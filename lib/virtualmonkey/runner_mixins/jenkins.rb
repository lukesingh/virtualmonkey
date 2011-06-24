module VirtualMonkey
  module Mixin
    module Jenkins
      include VirtualMonkey::Mixin::UnifiedApplication
  
      # Stolen from ::EBS need to consolidate or dr_toolbox needs a terminate script to include ::EBS instead
      # take the lineage name, find all snapshots and sleep until none are in the pending state.
      def wait_for_snapshots
        timeout=1500
        step=10
        while timeout > 0
          puts "Checking for snapshot completed"
          snapshots =find_snapshots
          status = snapshots.map { |x| x.aws_status } 
          break unless status.include?("pending")
          sleep step
          timeout -= step
        end
        raise "FATAL: timed out waiting for all snapshots in lineage #{@lineage} to complete" if timeout == 0
      end
  
      # Find all snapshots associated with this deployment's lineage
      def find_snapshots
        unless @lineage
          s = @servers.first
          kind_params = s.transform_parameters(s.parameters)
          @lineage = kind_params['DB_LINEAGE_NAME'].gsub(/text:/, "")
        end
        snapshots = Ec2EbsSnapshot.find_by_cloud_id(@servers.first.cloud_id).select { |n| n.nickname =~ /#{@lineage}.*$/ }
      end
  
      def set_variation_lineage
        @lineage = "testlineage#{resource_id(@deployment)}"
        obj_behavior(@deployment, :set_input, "block_device/lineage", "text:#{@lineage}")
      end
  
      def set_variation_container
        @container = "testlineage#{resource_id(@deployment)}"
        obj_behavior(@deployment, :set_input, "block_device/storage_container", "text:#{@container}")
      end
  
      # Pick a storage_type depending on what cloud we're on.
      def set_variation_storage_type
        cid = VirtualMonkey::Toolbox::determine_cloud_id(s_one)
        if cid == 232
          @storage_type = "ros"
          obj_behavior(@deployment, :set_input, "JENKINS_BACKUP_TYPE", "text:cloud_files")
        else
          pick = rand(100000) % 2
          if pick == 1
            @storage_type = "ros"
            obj_behavior(@deployment, :set_input, "JENKINS_BACKUP_TYPE", "text:s3")
          else
            @storage_type = "volume"
            obj_behavior(@deployment, :set_input, "JENKINS_BACKUP_TYPE", "text:ebs")
          end
        end
        puts "STORAGE_TYPE: #{@storage_type}"
   
        obj_behavior(@deployment, :set_input, "block_device/storage_type", "text:#{@storage_type}")
      end
  
      def test_s3
      # run_script("do_force_reset", s_one)
      #  sleep 10
      # run_script("setup_lvm_device_ec2_ephemeral", s_one)
        options = {
                "JENKINS_BACKUP_TYPE" => "text:s3"
        }
        probe(s_one, "touch /mnt/storage/monkey_was_here")
        sleep 10
       run_script("backup", s_one, options)
        sleep 10
       do_reset
       run_script("restore", s_one, options)
        # Restore spawns other scripts, so to make sure it's done, let's run another!
       run_script("service_restart", s_one)
        probe(s_one, "test -f /mnt/storage/monkey_was_here") do |result, status|
          raise "FATAL: no files found in the backup #{result} #{status}" if status != 0
          true
        end
      end
  
      def test_ebs
        # EBS is already setup, to save time we'll skip the force_reset
        run_script("do_force_reset", s_one)
        #sleep 10
        run_script("setup_lvm_device_ebs", s_one)
        options = {
                "JENKINS_BACKUP_TYPE" => "text:ebs"
        }      
        probe(s_one, "touch /mnt/storage/monkey_was_here")
        sleep 10
       run_script("backup", s_one, options)
        wait_for_snapshots
       do_reset
  # need to wait here for the volume status to settle (detaching)
        sleep 200
       run_script("restore", s_one, options)
        # Restore spawns other scripts, so to make sure it's done, let's run another!
       run_script("service_restart", s_one)
        probe(s_one, "test -f /mnt/storage/monkey_was_here") do |result, status|
          raise "FATAL: no files found in the backup #{result} #{status}" if status != 0
          true
        end
      end
  
      def test_cloud_files
      # run_script("do_force_reset", s_one)
      #  sleep 10
      # run_script("setup_lvm_device_rackspace", s_one)
        options = {
                "JENKINS_BACKUP_TYPE" => "text:cloud_files"
        }
        probe(s_one, "touch /mnt/storage/monkey_was_here")
        sleep 10
       run_script("backup", s_one, options)
        sleep 10
       do_reset
       run_script("restore", s_one, options)
        # Restore spawns other scripts, so to make sure it's done, let's run another!
       run_script("service_restart", s_one)
        probe(s_one, "test -f /mnt/storage/monkey_was_here") do |result, status|
          raise "FATAL: no files found in the backup #{result} #{status}" if status != 0
          true
        end
      end
  
      # pick the right set of tests depending on what cloud we're on
      def test_multicloud
        cid = VirtualMonkey::Toolbox::determine_cloud_id(s_one)
        if cid == 232
          test_cloud_files
        else
          if @storage_type == "ros"
            test_s3
          elsif @storage_type == "volume"
            test_ebs
          end
        end
      end
  
      def do_reset
       do_service_stop;
       run_script("do_force_reset", s_one)
        sleep 10
      end
  
      def do_service_restart
       run_script('service_restart', s_one)
      end
  
      def do_service_stop
       run_script('service_stop', s_one)
      end
  
      def do_prep
       run_script('setup_block_device', s_one)
       run_script('move_datadir', s_one)
      end
  
  # Check for specific Jenkins data.
      def check_app_monitoring
        app_plugins = [
                          {"plugin_name"=>"jenkins", "plugin_type"=>"threads"},
                          {"plugin_name"=>"java.lang-jenkins-Threading", "plugin_type"=>"gauge-Threads"}
                        ]
        @servers.each do |server|
          unless server.multicloud
            app_plugins.each do |plugin|
              monitor = obj_behavior(server, :get_sketchy_data, {'start' => -60,
                                                                 'end' => -20,
                                                                 'plugin_name' => plugin['plugin_name'],
                                                                 'plugin_type' => plugin['plugin_type']})
              value = monitor['data']['value']
              raise "No #{plugin['plugin_name']}-#{plugin['plugin_type']} data" unless value.length > 0
              # Need to check for that there is at least one non 0 value returned.
              for nn in 0...value.length
                if value[nn] > 0
                  break
                end
              end
              raise "No #{plugin['plugin_name']}-#{plugin['plugin_type']} time" unless nn < value.length
              puts "Monitoring is OK for #{plugin['plugin_name']}-#{plugin['plugin_type']}"
            end
          end
        end
      end
  
      def test_http
       test_http_response("Create an account", "#{s_one.dns_name}:3389/login", 3389)
      end
    end
  end
end 
