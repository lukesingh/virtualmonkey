if File.exists?("/var/spool/cloud/user-data")
  require '/var/spool/cloud/user-data'
  require '/var/spool/cloud/meta-data-cache'
  ENV['I_AM_IN_EC2'] = "true"
else
  ENV['RS_API_URL'] = "#{ENV['USER']}-#{`hostname`}".strip
end

module VirtualMonkey
  module Toolbox
    extend self

    # Check for API 0.1 Access
    def api0_1?
      unless class_variable_defined?("@@api0_1")
        begin
          Ec2SshKeyInternal.find_all
          @@api0_1 = true
        rescue
          @@api0_1 = false
        end
      end
      return @@api0_1
    end

    # Check for API 1.0 Access
    def api1_0?
      unless class_variable_defined?("@@api1_0")
        begin
          Ec2SecurityGroup.find_all
          @@api1_0 = true
        rescue
          @@api1_0 = false
        end
      end
      return @@api1_0
    end

    # Check for API 1.5 Beta Access
    def api1_5?
      unless class_variable_defined?("@@api1_5")
        begin
          Cloud.find_all
          @@api1_5 = true
        rescue
          @@api1_5 = false
        end
      end
      return @@api1_5
    end

    # Initializes most of the important class variables
    def setup_paths
      @@cloud_vars_dir = File.join("config", "cloud_variables")
      @@ssh_dir = File.join(File.expand_path("~"), ".ssh")
      @@sgs_file = File.join(@@cloud_vars_dir, "security_groups.json")
      @@dcs_file = File.join(@@cloud_vars_dir, "datacenters.json")
      @@keys_file = File.join(@@cloud_vars_dir, "ssh_keys.json")
      @@rest_yaml = File.join(File.expand_path("~"), ".rest_connection", "rest_api_config.yaml")
    end

    # Query for available clouds
    def get_available_clouds(up_to = 1000000)
      setup_paths()
      unless class_variable_defined?("@@clouds")
        @@clouds = [{"cloud_id" => 1, "name" => "AWS US-East"},
                    {"cloud_id" => 2, "name" => "AWS EU"},
                    {"cloud_id" => 3, "name" => "AWS US-West"},
                    {"cloud_id" => 4, "name" => "AWS AP-Singapore"},
                    {"cloud_id" => 5, "name" => "AWS AP-Tokyo"}]
        @@clouds += Cloud.find_all.map { |c| {"cloud_id" => c.cloud_id.to_i, "name" => c.name} } if api1_5?
      end
      @@clouds.select { |h| h["cloud_id"] <= up_to }
    end

    # Determine cloud_id for a server regardless of if it's operational or not
    def determine_cloud_id(server)
      server.settings
      ret = nil
      return server.cloud_id if server.cloud_id
      # API 1.5 has cloud_id under .settings even on inactive server, so must be API 1.0
      cloud_ids = get_available_clouds(10).map { |hsh| hsh["cloud_id"] }

      # Try ssh keys
      if server.ec2_ssh_key_href and api0_1?
        ref = server.ec2_ssh_key_href
        cloud_ids.each { |cloud|
          if Ec2SshKeyInternal.find_by_cloud_id(cloud.to_s).select { |o| o.href == ref }.first
            ret = cloud
          end
        }
      end

      return ret if ret
      # Try security groups
      if server.ec2_security_groups_href
        server.ec2_security_groups_href.each { |sg|
          cloud_ids.each { |cloud|
            if Ec2SecurityGroup.find_by_cloud_id(cloud.to_s).select { |o| o.href == sg }.first
              ret = cloud
            end
          }
        }
      end

      return ret if ret
      raise "Could not determine cloud_id...try setting an ssh key or security group"
    end

    # If virtualmonkey is running in EC2, sets some environment variables and returns a Server object for itself
    def find_myself_in_api
      if ENV['I_AM_IN_EC2']
        myself = Server.find_with_filter('aws_id' => ENV['EC2_INSTANCE_ID']).first
        if myself
          my_deploy = Deployment.find(myself['deployment_href'])
          ENV['MONKEY_SELF_SERVER_HREF'] = myself['href']
          ENV['MONKEY_SELF_DEPLOYMENT_HREF'] = myself['deployment_href']
          ENV['MONKEY_SELF_DEPLOYMENT_NAME'] = my_deploy.nickname
          return myself
        end
      end
      return false
    end

    # Generates temporary ssh keys to use for ssh'ing into generated servers. ssh_key_id_ary is a Hash of
    # the form: {"1" => "0000", "2" => "0001", ... } or nil
    # NOTE: for some reason, you looked up `git ls-files`
    def generate_ssh_keys(single_cloud = nil, ssh_key_id_ary = nil)
      cloud_ids = get_available_clouds().map { |hsh| hsh["cloud_id"] }
      cloud_ids.reject! { |i| i != single_cloud } if single_cloud

      ssh_key_id_ary ||= {}
      multicloud_key_file = File.join(@@ssh_dir, "api_user_key")
      rest_settings = YAML::load(IO.read(@@rest_yaml))
      rest_settings[:ssh_keys] = [] unless rest_settings[:ssh_keys]
      multicloud_key_data = IO.read(multicloud_key_file) if File.exists?(multicloud_key_file)
      if File.exists?(@@keys_file)
        keys = JSON::parse(IO.read(@@keys_file))
      else
        keys = {}
      end

      cloud_ids.each { |cloud|
        if keys["#{cloud}"] and keys["#{cloud}"] != {} # We already have data for this cloud, skip
          puts "Data found for cloud #{cloud}. Skipping..."
          next
        end
        if cloud <= 10 # EC2 clouds
          key_name = "monkey-#{cloud}-#{ENV['RS_API_URL'].split("/").last}"
        else # GW clouds use a hard-coded key
          key_name = "api_user_key"
        end
        found = nil
        if cloud <= 10
          if api0_1?
            found = Ec2SshKeyInternal.find_by_cloud_id("#{cloud}").select { |o| o.aws_key_name =~ /#{key_name}/ }.first
          end
          if ssh_key_id_ary[cloud.to_s]
            k = Ec2SshKey[ssh_key_id_ary[cloud.to_s].to_i]
          else
            k = (found ? found : Ec2SshKey.create('aws_key_name' => key_name, 'cloud_id' => "#{cloud}"))
          end
          keys["#{cloud}"] = {"ec2_ssh_key_href" => k.href,
                              "parameters" =>
                                {"PRIVATE_SSH_KEY" => "key:#{key_name}:#{cloud}"}
                              }
          # Generate Private Key Files
          priv_key_file = File.join(@@ssh_dir, "monkey-cloud-#{cloud}")
          File.open(priv_key_file, "w") { |f| f.write(k.aws_material) } unless File.exists?(priv_key_file)
        else
          # Use API user's managed ssh key
          puts "Using API user's managed ssh key, make sure \"~/.ssh/#{key_name}\" exists!"
          keys["#{cloud}"] = {"parameters" =>
                                {"PRIVATE_SSH_KEY" => "key:publish-test:1"}
                              }
          begin
            found = McSshKey.find_by(:resource_uid, "#{cloud}") { |n| n =~ /publish-test/ }.first
            if ssh_key_id_ary[cloud.to_s]
              k = McSshKey[ssh_key_id_ary[cloud.to_s].to_i]
            else
              k = (found ? found : McSshKey.create('name' => key_name, 'cloud_id' => "#{cloud}"))
            end
            keys["#{cloud}"]["ssh_key_href"] = k.href
          rescue
            puts "Cloud #{cloud} doesn't support the resource 'ssh_key'"
          end
          priv_key_file = multicloud_key_file
        end

        `touch #{priv_key_file}`
        File.chmod(0700, priv_key_file)
        # Configure rest_connection config
        rest_settings[:ssh_keys] << priv_key_file unless rest_settings[:ssh_keys].include?(priv_key_file)
      }

      keys_out = keys.to_json(:indent => "  ",
                              :object_nl => "\n",
                              :array_nl => "\n")
      rest_out = rest_settings.to_yaml
      File.open(@@keys_file, "w") { |f| f.write(keys_out) }
      File.open(@@rest_yaml, "w") { |f| f.write(rest_out) }
    end

    # Destroys all monkey-generated ssh keys that are not in use by monkey-generated servers
    # NOTE: This is a dangerous, and slow function. Be absolutely sure this is what you want to do.
    def destroy_all_unused_monkey_keys
      raise "You cannot run this without API 0.1 Access" unless api0_1?
      cloud_ids = get_available_clouds(10).map { |hsh| hsh["cloud_id"] }

      puts "Go grab a snickers. This will take a while."
      monkey_keys = []
      cloud_ids.each { |c|
        monkey_keys += Ec2SshKeyInternal.find_by_cloud_id("#{c}").select { |obj| obj.aws_key_name =~ /monkey/ }
      }
      remaining_keys = monkey_keys.map { |k| k.href }

      all_servers = Server.find_all

      all_servers.each { |s|
        s.settings
        remaining_keys.reject! { |k| k.href == s.ec2_ssh_key_href }
      }
      remaining_keys.each { |href| Ec2SshKey.new('href' => href).destroy }
    end

    # Destroys this monkey's temporary generated ssh keys
    def destroy_ssh_keys
      cloud_ids = get_available_clouds(10).map { |hsh| hsh["cloud_id"] }

      rest_settings = YAML::load(IO.read(@@rest_yaml))

      key_name = "#{ENV['RS_API_URL'].split("/").last}"
      # TODO cloud < 10?
      if api0_1?
        found = []
        cloud_ids.each { |c|
          found += Ec2SshKeyInternal.find_by_cloud_id("#{c}").select { |obj| obj.aws_key_name =~ /#{key_name}/ }
        }
        key_hrefs = found.select { |k| k.aws_key_name =~ /monkey/ }.map { |k| k.href }
      else
        keys = JSON::parse(IO.read(@@keys_file)) if File.exists?(@@keys_file)
        keys.reject! { |cloud,hash| hash["ec2_ssh_key_href"].nil? }
        key_hrefs = keys.map { |cloud,hash| hash["ec2_ssh_key_href"] }
      end
      key_hrefs.each { |href|
        temp_key = Ec2SshKey.new('href' => href)
        temp_key.reload
        temp_key.destroy if temp_key.aws_key_name =~ /monkey/
      }
      File.delete(@@keys_file) if File.exists?(@@keys_file)
      rest_settings[:ssh_keys].each { |f| File.delete(f) if File.exists?(f) and f =~ /monkey/ }
    end

    # If this virtualmonkey is in EC2, will grab the same security groups attached to it to use for
    # generated servers (requires the same security group name in each cloud). Will default to the 'default'
    # security group for every cloud that doesn't have the named security group. use_this_sec_group should
    # be a string, or nil.
    def populate_security_groups(single_cloud = nil, use_this_sec_group = nil)
      cloud_ids = get_available_clouds().map { |hsh| hsh["cloud_id"] }
      cloud_ids.reject! { |i| i != single_cloud } if single_cloud

      sgs = (File.exists?(@@sgs_file) ? JSON::parse(IO.read(@@sgs_file)) : {}) 

      cloud_ids.each { |cloud|
        if sgs["#{cloud}"] and sgs["#{cloud}"] != {} # We already have data for this cloud, skip
          puts "Data found for cloud #{cloud}. Skipping..."
          next
        end
        if ENV['EC2_SECURITY_GROUPS']
          sg_name = "#{ENV['EC2_SECURITY_GROUPS']}"
        else
          sg_name = "default"
          puts "WARNING: You are not running in ec2, will use the 'default' security group."
        end
        sg_name = use_this_sec_group if use_this_sec_group
        if cloud <= 10
          found = Ec2SecurityGroup.find_by_cloud_id("#{cloud}").select { |o| o.aws_group_name =~ /#{sg_name}/ }.first
          if found
            sg = found
          else
            puts "Security Group '#{sg_name}' not found in cloud #{cloud}."
            default = Ec2SecurityGroup.find_by_cloud_id("#{cloud}").select { |o| o.aws_group_name =~ /default/ }.first
            raise "Security Group 'default' not found in cloud #{cloud}." unless default
            sg = default
          end 
          sgs["#{cloud}"] = {"ec2_security_groups_href" => sg.href }
        else
          begin
            found = McSecurityGroup.find_by(:name, "#{cloud}") { |n| n =~ /#{sg_name}/ }.first
            if found
              sg = found
            else
              puts "Security Group '#{sg_name}' not found in cloud #{cloud}."
              default = McSecurityGroup.find_by(:name, "#{cloud}") { |n| n =~ /default/ }.first
              raise "Security Group 'default' not found in cloud #{cloud}." unless default
              sg = default
            end 
            sgs["#{cloud}"] = {"security_group_hrefs" => [sg.href] }
          rescue Exception => e
            raise e if e.message =~ /Security Group.*not found/
            puts "Cloud #{cloud} doesn't support the resource 'security_group'"
            sgs["#{cloud}"] = {}
          end
        end 
      }

      sgs_out = sgs.to_json(:indent => "  ",
                            :object_nl => "\n",
                            :array_nl => "\n")

      File.open(@@sgs_file, "w") { |f| f.write(sgs_out) }
    end

    # Grabs the API hrefs of the datacenters for each cloud. API 1.5 only
    def populate_datacenters(single_cloud = nil)
      cloud_ids = get_available_clouds().map { |hsh| hsh["cloud_id"] }
      cloud_ids.reject! { |i| i != single_cloud } if single_cloud

      dcs = (File.exists?(@@dcs_file) ? JSON::parse(IO.read(@@dcs_file)) : {}) 

      cloud_ids.each { |cloud|
        if dcs["#{cloud}"] and dcs["#{cloud}"] != {} # We already have data for this cloud, skip
          puts "Data found for cloud #{cloud}. Skipping..."
          next
        end
        if cloud <= 10
          puts "Cloud #{cloud} doesn't support the resource 'datacenter'"
          dcs["#{cloud}"] = {}
        elsif api1_5?
          begin
            #TODO: Don't just take the first one, Datacenters are variations too (as are Hypervisors)
            found = McDatacenter.find_all("#{cloud}").first 
            dcs["#{cloud}"] = {"datacenter_href" => found.href}
          rescue
            puts "Cloud #{cloud} doesn't support the resource 'datacenter'"
            dcs["#{cloud}"] = {}
          end
        end 
      }

      dcs_out = dcs.to_json(:indent => "  ",
                            :object_nl => "\n",
                            :array_nl => "\n")

      File.open(@@dcs_file, "w") { |f| f.write(dcs_out) }
    end

    # Populates all cloud_vars (ssh_keys, security_groups, and datacenters) without overriding any manually
    # defined resources
    def populate_all_cloud_vars(force = false, options = {})
      get_available_clouds()

      aws_clouds = {}
      all_clouds = {}

      @@clouds.each { |c|
        puts "Generating SSH Keys for cloud #{c['cloud_id']}..."
        if force
          begin
            generate_ssh_keys(c['cloud_id'], options['ssh_key_ids'])
          rescue Exception => e
            puts "Got exception: #{e.message}"
            puts "Forcing continuation..."
          end
        else
          generate_ssh_keys(c['cloud_id'], options['ssh_key_ids'])
        end

        puts "Populating Security Groups for cloud #{c['cloud_id']}..."
        if force
          begin
            populate_security_groups(c['cloud_id'], options['security_group_name'])
          rescue Exception => e
            puts "Got exception: #{e.message}"
            puts "Forcing continuation..."
          end
        else
          populate_security_groups(c['cloud_id'], options['security_group_name'])
        end

        puts "Populating Datacenters for cloud #{c['cloud_id']}..."
        if force
          begin
            populate_datacenters(c['cloud_id'])
          rescue Exception => e
            puts "Got exception: #{e.message}"
            puts "Forcing continuation..."
          end
        else
          populate_datacenters(c['cloud_id'])
        end
        c['name'].gsub!(/[- ]/, "_")
        c['name'].gsub!(/_+/, "_")
        c['name'].downcase!
        single_file_name = File.join(@@cloud_vars_dir, "#{c['name']}.json")

        single_cloud_vars = {"#{c['cloud_id']}" => {}}
        if File.exists?(single_file_name)
          single_cloud_vars = JSON::parse(IO.read(single_file_name))
        end
        # Single File
        single_cloud_out = single_cloud_vars.to_json(:indent => "  ",
                                                     :object_nl => "\n",
                                                     :array_nl => "\n")
        # AWS Clouds
        aws_clouds.deep_merge!(single_cloud_vars) if c['cloud_id'] <= 10
        # All Clouds
        all_clouds.deep_merge!(single_cloud_vars)

        File.open(single_file_name, "w") { |f| f.write(single_cloud_out) }
      }
      aws_clouds_out = aws_clouds.to_json(:indent => "  ", :object_nl => "\n", :array_nl => "\n")
      all_clouds_out = all_clouds.to_json(:indent => "  ", :object_nl => "\n", :array_nl => "\n")
      File.open(File.join(@@cloud_vars_dir, "aws_clouds.json"), "w") { |f| f.write(aws_clouds_out) }
      File.open(File.join(@@cloud_vars_dir, "all_clouds.json"), "w") { |f| f.write(all_clouds_out) }
    end
  end
end
