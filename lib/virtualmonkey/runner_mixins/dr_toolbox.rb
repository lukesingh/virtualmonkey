module VirtualMonkey
  module Mixin
    module DrToolbox
  
      # Stolen from ::EBS need to consolidate or dr_toolbox needs a terminate script to include ::EBS instead
      # take the lineage name, find all snapshots and sleep until none are in the pending state.
      def wait_for_snapshots
        timeout=1500
        step=10
        while timeout > 0
          puts "Checking for snapshot completed"
          snapshots = behavior(:find_snapshots)
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
        snapshots = Ec2EbsSnapshot.find_by_cloud_id(@servers.first.cloud_id).select { |n| n.tags.include?({"name"=>"rs_backup:lineage=#{@lineage}"}) }
      end
  
      # Returns the timestamp of the latest snapshot for testing OPT_DB_RESTORE_TIMESTAMP_OVERRIDE
      def find_snapshot_timestamp(provider=:ebs)
        case provider
        when :ebs
          last_snap = behavior(:find_snapshots).last
          last_snap.tags.detect { |t| t["name"] =~ /timestamp=(\d+)$/ }
          timestamp = $1
        when :s3
          s3 = Fog::Storage.new(:provider => 'AWS')
          if dir = s3.directories.detect { |d| d.key == @container }
            dir.files.first.key =~ /-([0-9]+\/[0-9]+)/
            timestamp = $1
          end
        when :cloud_files
          cloud_files = Fog::Storage.new(:provider => 'Rackspace')
          if dir = cloud_files.directories.detect { |d| d.key == @container }
            dir.files.first.key =~ /-([0-9]+\/[0-9]+)/
            timestamp = $1
          end
        else
          raise "FATAL: Provider #{provider.to_s} not supported."
        end
        return timestamp
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
        else
          pick = rand(100000) % 2
          if pick == 1
            @storage_type = "ros"
          else
            @storage_type = "volume"
          end
        end
        puts "STORAGE_TYPE: #{@storage_type}"
        @storage_type = ENV['STORAGE_TYPE'] if ENV['STORAGE_TYPE']
        @deployment.nickname += "-STORAGE_TYPE_#{@storage_type}"
        @deployment.save
   
        obj_behavior(@deployment, :set_input, "block_device/storage_type", "text:#{@storage_type}")
      end
  
      def test_s3
      #  behavior(:run_script, "do_force_reset", s_one)
      #  sleep 10
        behavior(:run_script, "setup_block_device", s_one)
        sleep 10
        probe(s_one, "dd if=/dev/urandom of=/mnt/storage/monkey_was_here bs=4M count=200")
        sleep 10
        behavior(:run_script, "do_backup_s3", s_one)
        sleep 10
        behavior(:run_script, "do_force_reset", s_one)
        sleep 10
        behavior(:run_script, "do_restore_s3", s_one)
        probe(s_one, "ls /mnt/storage") do |result, status|
          raise "FATAL: no files found in the backup" if result == nil || result.empty?
          true
        end
        behavior(:run_script, "do_force_reset", s_one)
        sleep 10
        behavior(:run_script, "do_restore_s3", s_one, {"block_device/timestamp_override" => "text:#{find_snapshot_timestamp(:s3)}" })
        probe(s_one, "ls /mnt/storage") do |result, status|
          raise "FATAL: no files found in the backup" if result == nil || result.empty?
          true
        end
      end
  
      def test_ebs
        # EBS is already setup, to save time we'll skip the force_reset
        #behavior(:run_script, "do_force_reset", s_one)
        #sleep 10
        behavior(:run_script, "setup_block_device", s_one)
        probe(s_one, "dd if=/dev/urandom of=/mnt/storage/monkey_was_here bs=4M count=500")
        sleep 100
        behavior(:run_script, "do_backup_ebs", s_one)
        wait_for_snapshots
        sleep 100
        behavior(:run_script, "do_force_reset", s_one)
  # need to wait here for the volume status to settle (detaching)
        sleep 400
        behavior(:run_script, "do_restore_ebs", s_one)
        probe(s_one, "ls /mnt/storage") do |result, status|
          raise "FATAL: no files found in the backup" if result == nil || result.empty?
          true
        end
        behavior(:run_script, "do_force_reset", s_one)
        sleep 400
        behavior(:run_script, "do_restore_ebs", s_one, {"block_device/timestamp_override" => "text:#{find_snapshot_timestamp(:ebs)}" })
        probe(s_one, "ls /mnt/storage") do |result, status|
          raise "FATAL: no files found in the backup" if result == nil || result.empty?
          true
        end
      end
  
      def test_cloud_files
      #  behavior(:run_script, "do_force_reset", s_one)
      #  sleep 10
        behavior(:run_script, "setup_block_device", s_one)
        sleep 10
        probe(s_one, "dd if=/dev/urandom of=/mnt/storage/monkey_was_here bs=4M count=200")
        sleep 10
        behavior(:run_script, "do_backup_cloud_files", s_one)
        sleep 10
        behavior(:run_script, "do_force_reset", s_one)
        sleep 10
        behavior(:run_script, "do_restore_cloud_files", s_one)
        probe(s_one, "ls /mnt/storage") do |result, status|
          raise "FATAL: no files found in the backup" if result == nil || result.empty?
          true
        end
        behavior(:run_script, "do_force_reset", s_one)
        sleep 10
        behavior(:run_script, "do_restore_cloud_files", s_one, {"block_device/timestamp_override" => "text:#{find_snapshot_timestamp(:cloud_files)}" })
        probe(s_one, "ls /mnt/storage") do |result, status|
          raise "FATAL: no files found in the backup" if result == nil || result.empty?
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
  
      def test_continuous_backups
        cid = VirtualMonkey::Toolbox::determine_cloud_id(s_one)
        if cid == 232
          test_continuous_backups_cloud_files
        else
          if @storage_type == "ros"
            test_continuous_backups_s3
          elsif @storage_type == "volume"
            test_continuous_backups_ebs
          end
        end
      end
  
      def test_continuous_backups_cloud_files
        # Setup Backups for every minute
        opts = {"block_device/cron_backup_hour" => "text:*",
                "block_device/cron_backup_minute" => "text:*"}
        behavior(:run_script, "setup_continuous_backups_cloud_files", s_one, opts)
        cloud_files = Fog::Storage.new(:provider => 'Rackspace')
        # Wait for directory to be created
        sleep 120
        retries = 0
        until dir = cloud_files.directories.detect { |d| d.key == @container }
          retries += 1
          raise "FATAL: Retry count exceeded 10" unless retries < 10
          sleep 30
        end
        # get file count
        count = dir.files.length
        sleep 120
        dir.files.reload
        raise "FATAL: Failed Continuous Backup Enable Test" unless dir.files.length > count
        # Disable cron job
        behavior(:run_script, "do_disable_continuous_backups_cloud_files", s_one)
        sleep 120
        count = dir.files.length
        sleep 120
        dir.files.reload
        raise "FATAL: Failed Continuous Backup Disable Test" unless dir.files.length == count
      end
  
      def test_continuous_backups_s3
        # Setup Backups for every minute
        opts = {"block_device/cron_backup_hour" => "text:*",
                "block_device/cron_backup_minute" => "text:*"}
        behavior(:run_script, "setup_continuous_backups_s3", s_one, opts)
        cloud_files = Fog::Storage.new(:provider => 'AWS')
        # Wait for directory to be created
        sleep 120
        retries = 0
        until dir = cloud_files.directories.detect { |d| d.key == @container }
          retries += 1
          raise "FATAL: Retry count exceeded 10" unless retries < 10
          sleep 30
        end
        # get file count
        count = dir.files.length
        sleep 120
        dir.files.reload
        raise "FATAL: Failed Continuous Backup Enable Test" unless dir.files.length > count
        # Disable cron job
        behavior(:run_script, "do_disable_continuous_backups_s3", s_one)
        sleep 120
        count = dir.files.length
        sleep 120
        dir.files.reload
        raise "FATAL: Failed Continuous Backup Disable Test" unless dir.files.length == count
      end
  
      def test_continuous_backups_ebs
        # Setup Backups for every minute
        opts = {"block_device/cron_backup_hour" => "text:*",
                "block_device/cron_backup_minute" => "text:*"}
        behavior(:run_script, "setup_continuous_backups_ebs", s_one, opts)
        # Wait for snapshots to be created
        sleep 300
        retries = 0
        snapshots = behavior(:find_snapshots)
        until snapshots.length > 0
          retries += 1
          raise "FATAL: Retry count exceeded 5" unless retries < 5
          sleep 100
          snapshots = behavior(:find_snapshots)
        end
        # get file count
        count = snapshots.length
        sleep 200
        raise "FATAL: Failed Continuous Backup Enable Test" unless behavior(:find_snapshots).length > count
        # Disable cron job
        behavior(:run_script, "do_disable_continuous_backups_ebs", s_one)
        sleep 200
        count = behavior(:find_snapshots).length
        sleep 200
        raise "FATAL: Failed Continuous Backup Disable Test" unless behavior(:find_snapshots).length == count
      end
  
      def release_container
        set_variation_container
        raise "FATAL: could not cleanup because @container was '#{@container}'" unless @container
        s3 = Fog::Storage.new(:provider => 'AWS')
        rax = Fog::Storage.new(:provider => 'Rackspace')
        delete_rax = rax.directories.all.select {|d| d.key =~ /^#{@container}/}
        delete_s3 = s3.directories.all.select {|d| d.key =~ /^#{@container}/}
        [delete_rax, delete_s3].each do |con|
          con.each do |dir|
            dir.files.each do |file|
              file.destroy
            end
            dir.destroy
          end
        end
      end
  
    end
  end
end 
