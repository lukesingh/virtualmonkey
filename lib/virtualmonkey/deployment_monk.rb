require 'rubygems'
require 'rest_connection'
require 'pp'

class DeploymentMonk
  attr_accessor :common_inputs
  attr_accessor :deployments

  # Returns an Array of Deployment objects whose nicknames start with @prefix
  def from_prefix
    variations = Deployment.find_by(:nickname) {|n| n =~ /^#{@prefix}/ }
    puts "loading #{variations.size} deployments matching your prefix"
    return variations
  end

  # Lists the nicknames of Array of Deployment objects whose nicknames start with prefix
  def self.list(prefix, verbose = false)
    deployments = Deployment.find_by(:nickname) {|n| n =~ /^#{prefix}/ }
    if verbose
      pp deployments.map { |d| { d.nickname => d.servers.map { |s| s.state } } }
    else
      pp deployments.map { |d| d.nickname }
    end
  end

  # Lists the nicknames of Array of Deployment objects whose nicknames start with @prefix
  def list(verbose = false)
    if verbose
      pp @deployments.map { |d| { d.nickname => d.servers.map { |s| s.state } } }
    else
      pp @deployments.map { |d| d.nickname }
    end
  end

  def initialize(prefix, server_templates = [], extra_images = [], suppress_monkey_warning = false, single_deployment = false)
    @clouds = []
    @single_deployment = single_deployment
    @prefix = prefix
    @deployments = from_prefix
    @server_templates = []
    @common_inputs = {}
    @variables_for_cloud = {}
    @ssh_keys, @security_groups, @datacenters = {}, {}, {}
    puts "single_deployment: true" if @single_deployment
    raise "Need either populated deployments or passed in server_template ids" if server_templates.empty? && @deployments.empty?

    # Get list of unique server_template ids
    if server_templates.empty?
      puts "loading server templates from all deployments"
      @deployments.each { |d| 
        d.reload
        d.servers_no_reload.each { |s|
          server_templates << s.server_template_href.split(/\//).last.to_i
        }
      }
      server_templates.uniq!
    end

    # Load ServerTemplate objects from names/ids
    server_templates.each do |st|
      if st =~ /[^0-9]/ #ServerTemplate Name was given
        sts_found << ServerTemplate.find_by(:nickname) { |n| n =~ /#{st}/ }
        raise "Found more than one ServerTemplate matching '#{st}'." unless sts_found.size == 1
        st = sts_found.first
      else #ServerTemplate ID was given
        st = ServerTemplate.find(st.to_i)
      end
      # Do not allow Servers using the VirtualMonkey ServerTemplate to be subject to monkey code
      unless suppress_monkey_warning
        raise "ABORTING: VirtualMonkey has been found in a deployment." if st.nickname =~ /virtual *monkey/i
      end
      @server_templates << st unless st.nickname =~ /virtual *monkey/i
    end
    raise "Error: To launch a single deployment a maximum of one server template is allowed " if ((@server_templates.length > 1) && @single_deployment)
  end

  def generate_variations(options = {})
    # Count the max number of images that we can select from
    dep_image_names = nil  # This variable holds the names of the images in the deployment
    @image_count = 0
    @server_templates.each do |st|
      new_st = ServerTemplateInternal.new(:href => st.href)
      st.multi_cloud_images = new_st.multi_cloud_images
      if options[:mci_override] && !options[:mci_override].empty?
        mci = MultiCloudImageInternal.new(:href => options[:mci_override].first)
        mci.reload
        multi_cloud_images = [mci]
      elsif options[:only]
        multi_cloud_images = new_st.multi_cloud_images.select { |mci| mci['name'] =~ /#{options[:only]}/ }
        raise "No MCI on ServerTemplate '#{new_st.nickname}' matches regex /#{options[:only]}/" if multi_cloud_images.empty?
      else
        multi_cloud_images = new_st.multi_cloud_images
      end
      @image_count = multi_cloud_images.size if multi_cloud_images.size > @image_count

      # Collect Supported Cloud ids
      multi_cloud_images.each { |mci|
        @clouds.concat( mci["multi_cloud_image_cloud_settings"].map { |s| 
          unless s["fingerprint"]
            ret = "#{s["cloud_id"]}"
          else
            ret = nil
          end
          [ret]
        })
      }
    end
    @clouds.flatten!
    @clouds.compact!
    @clouds.uniq!
    if options[:mci_override] && !options[:mci_override].empty?
      @image_count = options[:mci_override].size
    end
    
    dep_tempname = nil
    new_deploy = nil
    nick_name_holder = [] # this variable is used when we want to create a single deployment and we use it to name the deployment properly 
    deployment_created = false # this variable is used to control creating a single deployment 
    @image_count.times do |index|
      @clouds.each do |cloud|

        # Skip if the cloud hasn't been specified
        if @variables_for_cloud[cloud] == nil
          puts "Variables not found for cloud #{cloud}. Skipping..."
          next
        end

        # Skip if the selected MCI doesn't support the cloud
        mci_supports_cloud = true
        @server_templates.each do |st|
          new_st = ServerTemplateInternal.new(:href => st.href)
          if options[:mci_override] && !options[:mci_override].empty?
            mci = MultiCloudImageInternal.new(:href => options[:mci_override][index])
	          mci.reload
          elsif options[:only]
            subset = new_st.multi_cloud_images.select { |mci| mci['name'] =~ /#{options[:only]}/ }
            if subset[index]
              mci = subset[index]
            else
              mci = subset[0]
            end
          elsif new_st.multi_cloud_images[index]
            mci = new_st.multi_cloud_images[index]
          else
            mci = new_st.multi_cloud_images[0]
          end
          mci_check = false
          mci["multi_cloud_image_cloud_settings"].each { |setting|
            mci_check ||= (setting["cloud_id"].to_i == cloud.to_i)
          }
          mci_supports_cloud &&= mci_check
        end
        unless mci_supports_cloud
          puts "MCI doesn't contain an image that supports cloud #{cloud}. Skipping..."
          next
        end

        # Create Deployment for this MCI and cloud
        if @single_deployment && !deployment_created
          dep_tempname = "#{@prefix}-cloud_#{cloud}-#{rand(1000000)}-"
          dep_tempname = "#{@prefix}-cloud_multicloud-#{rand(1000000)}-" if @clouds.length > 1
          new_deploy = Deployment.create(:nickname => dep_tempname)
          @deployments << new_deploy
          deployment_created = true
        elsif !@single_deployment
          dep_tempname = "#{@prefix}-cloud_#{cloud}-#{rand(1000000)}-"
          new_deploy = Deployment.create(:nickname => dep_tempname)
          @deployments << new_deploy
        end

        dep_image_list = []
        @server_templates.each do |st|
          nick_name_holder << st.nickname.gsub(/ /,'_')  ## place the nickname into the array
          #Select an MCI to use
          if options[:mci_override] && !options[:mci_override].empty?
            mci = MultiCloudImageInternal.new(:href => options[:mci_override][index])
	          mci.reload
            use_this_image_setting = mci['multi_cloud_image_cloud_settings'].detect { |setting| setting["image_href"].include?("cloud_id=#{cloud}") }
            use_this_image = use_this_image_setting["image_href"]
            use_this_instance_type = use_this_image_setting["aws_instance_type"]
            dep_image_list << MultiCloudImage.find(options[:mci_override][index]).name.gsub(/ /,'_')
              dep_image_names =  MultiCloudImage.find(options[:mci_override][index]).name.gsub(/ /,'_')
          elsif options[:only]
            subset = st.multi_cloud_images.select { |mci| mci['name'] =~ /#{options[:only]}/ }
            if subset[index]
              dep_image_list << subset[index]['name'].gsub(/ /,'_')
               dep_image_names =  subset[index]['name'].gsub(/ /,'_')
              use_this_image = subset[index]['href']
            else
              use_this_image = subset[0]['href']
            end
          elsif st.multi_cloud_images[index]
            dep_image_list << st.multi_cloud_images[index]['name'].gsub(/ /,'_')
            dep_image_names = st.multi_cloud_images[index]['name'].gsub(/ /,'_')
            use_this_image = st.multi_cloud_images[index]['href']
          else
            use_this_image = st.multi_cloud_images[0]['href']
          end

          # Load Cloud Variables from all_clouds.json
          load_vars_for_cloud(cloud)

          # Merge cloud_var parameters OVER common_inputs
          inputs = []
          @common_inputs.deep_merge(@variables_for_cloud[cloud]['parameters']).each do |key,val|
            inputs << { "name" => key, "value" => val }
          end

          #Set Server Creation Parameters
          serv_name = "#{@prefix[0...2]}-#{rand(10000)}-#{st.nickname}-#{dep_image_names}" if @single_deployment
          serv_name = "#{@prefix[0...2]}-#{rand(10000)}-#{st.nickname}" unless @single_deployment
          serv_name = "#{@prefix[0...2]}-#{rand(100)}" if cloud.to_s == "232"
          server_params = { "nickname" => serv_name,
                            "deployment_href" => new_deploy.href.dup,
                            "server_template_href" => st.href.dup,
                            "cloud_id" => cloud,
                            "inputs" => inputs,
                            "mci_href" => use_this_image
                            #"ec2_image_href" => image['image_href'],
                            #"instance_type" => image['aws_instance_type']
                          }

          # If overriding the multicloudimage need to specify the ec2 image href because you can't set an MCI that's not in the ServerTemplate
          if options[:mci_override] && !options[:mci_override].empty?
            server_params.reject! {|k,v| k == "mci_href"}
            server_params["ec2_image_href"] = use_this_image
            server_params["instance_type"] = use_this_instance_type
          end

          # This rescue block can be removed after the VM ServerTemplate defaults to multicloud rest_connection
          begin
            server = ServerInterface.new(cloud).create(server_params.deep_merge(@variables_for_cloud[cloud]))
          rescue Exception => e
            puts "Got exception: #{e.message}"
            puts "Backtrace: #{e.backtrace.join("\n")}"
          end

          # AWS Cloud-specific Code XXX LEGACY XXX
          if cloud.to_i < 10
            server = Server.create(server_params.deep_merge(@variables_for_cloud[cloud])) unless server
            # since the create call does not set the parameters, we need to set them separate
            server.set_inputs(@variables_for_cloud[cloud]['parameters'])
            # uses a special internal call for setting the MCI on the server
            sint = ServerInternal.new(:href => server.href)
            sint.set_multi_cloud_image(use_this_image) unless options[:mci_override] && !options[:mci_override].empty?

            # finally, set the spot price
            unless options[:no_spot]
              server.reload
              server.settings
              if server.ec2_instance_type =~ /small/ 
                server.max_spot_price = "0.085"
              elsif server.ec2_instance_type =~ /large/
                server.max_spot_price = "0.38"
              end
              server.pricing = "spot"
              server.parameters = {}
              server.save
            end
          end

          # Add image names to the deployment nickname
          new_deploy.nickname = dep_tempname + dep_image_list.uniq.join("_AND_")
          new_deploy.save

          # Set the inputs at the deployment level
          new_deploy.set_inputs(@common_inputs.deep_merge(@variables_for_cloud[cloud]['parameters']))
        end
      end
    end
    if @single_deployment
      new_deploy.nickname = dep_tempname + nick_name_holder.uniq.join("_AND_") + "-ALL_IN_ONE"
      new_deploy.save
    end
  end

  def load_common_inputs(file)
    @common_inputs.deep_merge! JSON.parse(IO.read(file))
  end

  def load_cloud_variables(file)
    @variables_for_cloud.deep_merge! JSON.parse(IO.read(file))
  end

  def load_clouds(cloud_ids)
    VirtualMonkey::Toolbox::populate_all_cloud_vars(:force)
    all_clouds = JSON::parse(IO.read(File.join("config","cloud_variables","all_clouds.json")))
    cloud_ids.each { |id| @variables_for_cloud.deep_merge!(id.to_s => all_clouds[id.to_s]) }
  end

  def update_inputs
    @deployments.each do |d|
      c_inputs = @common_inputs.dup

      # Set inputs at the Deployment level
      # If deployment has the string "-cloud_#-", then collect inputs from cloud_vars
      if d.cloud_id and load_vars_for_cloud(d.cloud_id)
        set_inputs(d, c_inputs.deep_merge(@variables_for_cloud[d.cloud_id.to_s]['parameters']))
      else
        set_inputs(d, c_inputs)
      end

      # Set inputs at the Server level
      d.servers.each { |s|
        cid = VirtualMonkey::Toolbox::determine_cloud_id(s).to_s
        cv_inputs = (load_vars_for_cloud(cid) ? @variables_for_cloud[cid]['parameters'] : {})
        set_inputs(s, c_inputs.deep_merge(cv_inputs))
      }
    end
  end

  def load_vars_for_cloud(cloud)
    cloud = cloud.to_s
    return nil unless @variables_for_cloud[cloud]
    unless @ssh_keys[cloud] and @ssh_keys[cloud] != {}
      VirtualMonkey::Toolbox::generate_ssh_keys(cloud)
      @ssh_keys = JSON::parse(IO.read(File.join("config","cloud_variables","ssh_keys.json")))
    end
    unless @security_groups[cloud] and @security_groups[cloud] != {}
      VirtualMonkey::Toolbox::populate_security_groups(cloud)
      @security_groups = JSON::parse(IO.read(File.join("config","cloud_variables","security_groups.json")))
    end
    unless @datacenters[cloud] and @datacenters[cloud] != {}
      VirtualMonkey::Toolbox::populate_datacenters(cloud)
      @datacenters = JSON::parse(IO.read(File.join("config","cloud_variables","datacenters.json")))
    end
    @variables_for_cloud[cloud].deep_merge!(@ssh_keys[cloud])
    @variables_for_cloud[cloud].deep_merge!(@security_groups[cloud])
    @variables_for_cloud[cloud].deep_merge!(@datacenters[cloud])
    true
  end

  def destroy_all
    @deployments.each { |v|
      v.servers_no_reload.each { |s|
        s.wait_for_state("stopped")
      }
      v.destroy
    }
    @deployments = []
  end

  def set_server_params
    @deployments.each do |d|
      d.servers.each { |s|
        cid = VirtualMonkey::Toolbox::determine_cloud_id(s).to_s
        s.update(@variables_for_cloud[cid]) if load_vars_for_cloud(cid)
      }
    end
  end

end
