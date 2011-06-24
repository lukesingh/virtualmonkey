module VirtualMonkey
  module Mixin
    module EBS
      include VirtualMonkey::Mixin::DeploymentBase
      attr_accessor :stripe_count
      attr_accessor :volume_size
      attr_accessor :mount_point
      attr_accessor :lineage
  
      # sets the stripe count for the deployment
      # * count<~String> eg. "3"
      def set_variation_stripe_count(count)
        @stripe_count = count
        obj_behavior(@deployment, :set_input, "EBS_STRIPE_COUNT", "text:#{@stripe_count}")
      end
  
      # sets the volume size n GB for the runner
      # * kind<~Num> 
      def set_variation_volume_size(size)
        @volume_size = size
      end
  
      # sets the EBS mount point for the runner
      # * kind<~String> 
      def set_variation_mount_point(mnt)
        @mount_point = mnt
      end
  
      # sets the lineage for the deployment
      # * kind<~String> can be "chef" or nil
      def set_variation_lineage(kind = nil)
        @lineage = "testlineage#{resource_id(@deployment)}"
        if kind
          raise "Only support nil kind for ebs lineage"
        else
          obj_behavior(@deployment, :set_input, 'EBS_LINEAGE', "text:#{@lineage}")
          # unset all server level inputs in the deployment to ensure use of 
          # the setting from the deployment level
          @servers.each do |s|
            obj_behavior(s, :set_input, 'EBS_LINEAGE', "text:")
          end
        end
      end
  
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
          kind_params = s.parameters
          @lineage = kind_params['DB_LINEAGE_NAME'].gsub(/text:/, "")
        end
        snapshots = Ec2EbsSnapshot.find_by_cloud_id(@servers.first.cloud_id).select { |n| n.nickname =~ /#{@lineage}.*$/ }
      end
  
      # Returns the timestamp of the latest snapshot for testing OPT_DB_RESTORE_TIMESTAMP_OVERRIDE
      def find_snapshot_timestamp
        last_snap =find_snapshots.last
        last_snap.tags.detect { |t| t["name"] =~ /timestamp=(\d+)$/ }
        timestamp = $1
      end
  
      # creates a EBS stripe on the server
      # * server<~Server> the server to create stripe on
      def create_stripe_volume(server)
        options = { "EBS_MOUNT_POINT" => "text:#{@mount_point}",
                "EBS_STRIPE_COUNT" => "text:#{@stripe_count}",
                "EBS_TOTAL_VOLUME_GROUP_SIZE" => "text:#{@volume_size}",
                "EBS_LINEAGE" => "text:#{@lineage}" }
       run_script('create_stripe', server, options)
      end
  
      # * server<~Server> the server to restore to
      def restore_from_backup(server,force)
        options = { "EBS_MOUNT_POINT" => "text:#{@mount_point}",
                "OPT_DB_FORCE_RESTORE" => "text:#{force}",
                "EBS_LINEAGE" => "text:#{@lineage}" }
       run_script('restore', server, options)
      end
  
      # * server<~Server> the server to restore to
      def restore_and_grow(server,new_size,force)
        options = { "EBS_MOUNT_POINT" => "text:#{@mount_point}",
                "EBS_TOTAL_VOLUME_GROUP_SIZE" => "text:#{new_size}",
                "OPT_DB_FORCE_RESTORE" => "text:#{force}",
                "EBS_LINEAGE" => "text:#{@lineage}" }
       run_script('grow_volume', server, options)
      end
  
      # Verify that the volume has special data on it.
      def test_volume_data(server)
        probe(server, "test -f #{@mount_point}/data.txt")
      end
  
      # Verify that the volume is the expected size
      def test_volume_size(server,expected_size)
        error_range = 0.05
        puts "Testing with a +/- #{error_range * 100}% margin of error: #{@mount_point} #{expected_size}GB"
        expected_size *= 1048576 # expected_size is given in GB, df is given in KB
        probe(server, "df -k | grep #{@mount_point}") { |response,status|
          val = response.match(/[0-9]+/)[0].to_i
          ret = (val < (expected_size * (1.0 + error_range)) and val > (expected_size * (1.0 - error_range)))
          ret
        }
      end
  
      # Writes data to the EBS volume so snapshot restores can be verified
      # Not sure what to write...... Maybe pass a string to write to a file??..
      def populate_volume(server)
        probe(server, " echo \"blah blah blah\" > #{@mount_point}/data.txt")
      end
  
      # * server<~Server> the server to terminate
      def terminate_server(server)
        options = { "EBS_MOUNT_POINT" => "text:#{@mount_point}",
                "EBS_TERMINATE_SAFETY" => "text:off" }
       run_script('terminate', server, options)
      end
  
      # Use the termination script to stop all the servers (this cleans up the volumes)
      def stop_all(wait=true)
        @servers.each do |s|
         terminate_server(s) if s.state == 'operational' || s.state == 'stranded'
        end
        @servers.each { |s| obj_behavior(s, :wait_for_state, "stopped") }
        # unset dns in our local cached copy..
        @servers.each { |s| s.params['dns-name'] = nil }
      end
  
      def test_restore_grow
        grow_to_size=100
       restore_and_grow(s_three, grow_to_size, false)
       test_volume_data(s_three)
       test_volume_size(s_three, grow_to_size)
      end
  
      def test_restore
       restore_from_backup(s_two, false)
       test_volume_data(s_two)
      end
  
      def create_backup
       run_script("backup", s_one)
       wait_for_snapshots
      end
  
      # Create a stripe and write some data to it
      def create_stripe
       create_stripe_volume(s_one)
       populate_volume(s_one)
      end
  
      def test_backup_script_operations
        backup_script="/usr/local/bin/ebs-backup.rb"
        # create backup scripts
       run_script("create_backup_scripts", s_one)
        probe(s_one, "test -x #{backup_script}")
        # enable continuous backups
       run_script("continuous_backup", s_one)
        probe(s_one, "egrep \"^[0-6].*#{backup_script}\" /etc/crontab")
        # freeze backups
       run_script("freeze", s_one)
        probe(s_one, "egrep \"^#[0-6].*#{backup_script}\" /etc/crontab")
        # unfreeze backups
       run_script("unfreeze", s_one)
        probe(s_one, "egrep \"^[0-6].*#{backup_script}\" /etc/crontab")
      end
  
      def run_reboot_operations
        obj_behavior(s_one, :reboot, true)
        obj_behavior(s_one, :wait_for_state, "operational")
       create_backup
      end
    end
  end
end
