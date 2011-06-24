module VirtualMonkey
  module Mixin
    module ChefMysql
      include VirtualMonkey::Mixin::DeploymentBase
      include VirtualMonkey::Mixin::EBS
      attr_accessor :scripts_to_run
      attr_accessor :db_ebs_prefix
  
      # sets the lineage for the deployment
      # * kind<~String> can be "chef" or nil
      def set_variation_lineage()
        @lineage = "testlineage#{resource_id(@deployment)}"
  puts "Set variation LINEAGE: #{@lineage}"
        obj_behavior(@deployment, :set_input, 'db_mysql/backup/lineage', "text:#{@lineage}")
      end
  
      def set_variation_container
        @container = "testlineage#{resource_id(@deployment)}"
  puts "Set variation CONTAINER: #{@container}"
        obj_behavior(@deployment, :set_input, "db_mysql/backup/storage_container", "text:#{@container}")
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
  
        @storage_type = ENV['STORAGE_TYPE'] if ENV['STORAGE_TYPE']
        puts "STORAGE_TYPE: #{@storage_type}"
        @deployment.nickname += "-STORAGE_TYPE_#{@storage_type}"
        @deployment.save
   
        obj_behavior(@deployment, :set_input, "db_mysql/backup/storage_type", "text:#{@storage_type}")
      end
  
      def test_s3
       run_script("setup_block_device", s_one)
        probe(s_one, "touch /mnt/storage/monkey_was_here")
        sleep 10
       run_script("do_backup_s3", s_one)
        sleep 10
       run_script("do_force_reset", s_one)
        sleep 10
       run_script("do_restore_s3", s_one)
        probe(s_one, "ls /mnt/storage") do |result, status|
          raise "FATAL: no files found in the backup" if result == nil || result.empty?
          true
        end
      end
  
      def test_ebs
       run_script("setup_block_device", s_one)
        probe(s_one, "touch /mnt/storage/monkey_was_here")
        sleep 100
       run_script("do_backup_ebs", s_one)
        wait_for_snapshots
        sleep 100
       run_script("do_force_reset", s_one)
  # need to wait here for the volume status to settle (detaching)
        sleep 400
       run_script("do_restore_ebs", s_one)
        probe(s_one, "ls /mnt/storage") do |result, status|
          raise "FATAL: no files found in the backup" if result == nil || result.empty?
          true
        end
      end
  
      def test_cloud_files
       run_script("setup_block_device", s_one)
        probe(s_one, "touch /mnt/storage/monkey_was_here")
        sleep 10
       run_script("do_backup_cloud_files", s_one)
        sleep 10
       run_script("do_force_reset", s_one)
        sleep 10
       run_script("do_restore_cloud_files", s_one)
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
      # creates a MySQL enabled EBS stripe on the server
      # * server<~Server> the server to create stripe on
  #XXX stripe is created during boot - this is not needed
  #    def create_stripe(server)
  #    end
  
      # creates a MySQL enabled EBS stripe on the server and uses the dumpfile to restore the DB
  #    def create_stripe_from_dumpfile(server)
  #    end
  
      # Performs steps necessary to bootstrap a MySQL Master server from a pristine state using a dumpfile.
      # * server<~Server> the server to use as MASTER
  #    def config_master_from_scratch_from_dumpfile(server)
  #     create_stripe_from_dumpfile(server)
  #      probe(server, "service mysqld start") # TODO Check that it started?
  #TODO the service name depends on the OS
  #      server.spot_check_command("service mysql start")
  #     run_query("create database mynewtest", server)
  #     set_master_dns(server)
  #      # This sleep is to wait for DNS to settle - must sleep
  #      sleep 120
  #     run_script("backup", server)
  #    end
  
      # Performs steps necessary to bootstrap a MySQL Master server from a pristine state.
      # * server<~Server> the server to use as MASTER
  #    def config_master_from_scratch(server)
  #     create_stripe(server)
  #      probe(server, "service mysqld start") # TODO Check that it started?
  #TODO the service name depends on the OS
  #      server.spot_check_command("service mysql start")
  #     run_query("create database mynewtest", server)
  #     set_master_dns(server)
  #      # This sleep is to wait for DNS to settle - must sleep
  #      sleep 120
  #     run_script("backup", server)
  #    end
  
      # Runs a mysql query on specified server.
      # * query<~String> a SQL query string to execute
      # * server<~Server> the server to run the query on 
      def run_query(query, server)
        query_command = "echo -e \"#{query}\"| mysql"
        probe(server, query_command)
      end
  
      # Sets DNS record for the Master server to point at server
      # * server<~Server> the server to use as MASTER
  #    def set_master_dns(server)
  #     run_script('master_init', server)
  #    end
  
      # Use the termination script to stop all the servers (this cleans up the volumes)
      def stop_all(wait=true)
        @servers.each { |s| obj_behavior(s, :stop) }
  
       wait_for_all("stopped") if wait
        # unset dns in our local cached copy..
        @servers.each { |s| s.params['dns-name'] = nil } 
      end
  
      # uses SharedDns to find an available set of DNS records and sets them on the deployment
      def setup_dns(domain)
  # TODO should we just use the ID instead of the full href?
        owner=@deployment.href
        @dns = SharedDns.new(domain)
        raise "Unable to reserve DNS" unless @dns.reserve_dns(owner)
        @dns.set_dns_inputs(@deployment)
      end
     
      def setup_block_device
  puts "SETUP_BLOCK_DEVICE"
       run_script("setup_block_device", s_one)
      end
  
      def do_backup
  puts "BACKUP"
       run_script("do_backup", s_one)
  puts "BAD BAD SLEEPING TIL SNAPSHOT IS COMPLETE"
        sleep 30
      end
  
      def do_restore
  puts "RESTORE"
       run_script("do_restore", s_one)
      end
  
      def do_force_reset
  puts "RESET"
       run_script("do_force_reset", s_one)
      end
  
      # releases records back into the shared DNS pool
      def release_dns
        @dns.release_dns
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
  
  
  #    def promote_server(server)
  #     run_script("promote", server)
  #    eu
  
  #    def slave_init_server(server)
  #     run_script("slave_init", server)
  #    end
  
  #    def create_migration_script
  #      options = { "DB_EBS_PREFIX" => "text:regmysql",
  #              "DB_EBS_SIZE_MULTIPLIER" => "text:1",
  #              "EBS_STRIPE_COUNT" => "text:#{@stripe_count}" }
  #     run_script('create_migrate_script', s_one, options)
  #    end
  
      # These are mysql specific checks (used by mysql_runner and lamp_runner)
      def run_checks
  puts "RUN_CHECKS"
        # check that mysql tmpdir is custom setup on all servers
  #      query = "show variables like 'tmpdir'"
  #      query_command = "echo -e \"#{query}\"| mysql"
  #      probe(@servers, query_command) { |result,st| result.include?("/mnt/mysqltmp") }
  #      @servers.each do |server|
  #        server.spot_check(query_command) { |result| raise "Failure: tmpdir was unset#{result}" unless result.include?("/mnt/mysqltmp") }
  #      end
  
  #      # check that mysql cron script exits success
  #      @servers.each do |server|
  #        chk1 = probe(server, "/usr/local/bin/mysql-binary-backup.rb --if-master --max-snapshots 10 -D 4 -W 1 -M 1 -Y 1")
  #
  #        chk2 = probe(server, "/usr/local/bin/mysql-binary-backup.rb --if-slave --max-snapshots 10 -D 4 -W 1 -M 1 -Y 1")
  #
  #        raise "CRON BACKUPS FAILED TO EXEC, Aborting" unless (chk1 || chk2) 
  #      end
  
        # check that logrotate has mysqlslow in it
  #      probe(@servers, "logrotate --force -v /etc/logrotate.d/mysql") { |out,st| out =~ /mysqlslow/ and st == 0 }
  #      probe(@servers, "logrotate --force -v /etc/logrotate.d/mysql-server") { |out,st| out =~ /mysqlslow/ and st == 0 }
  #      @servers.each do |server|
  #        res = server.spot_check_command("logrotate --force -v /etc/logrotate.d/mysql-server")
  #        raise "LOGROTATE FAILURE, exited with non-zero status" if res[:status] != 0
  #        raise "DID NOT FIND mysqlslow.log in the log rotation!" if res[:output] !~ /mysqlslow/
  #      end
  puts "RUN_CHECK DONE"
      end
  
  
  #    # check that mysql can handle 5000 concurrent connections (file limits, etc.)
  #    def run_mysqlslap_check
  #        probe(@servers, "mysqlslap  --concurrency=5000 --iterations=10 --number-int-cols=2 --number-char-cols=3 --auto-generate-sql --csv=/tmp/mysqlslap_q1000_innodb.csv --engine=innodb --auto-generate-sql-add-autoincrement --auto-generate-sql-load-type=mixed --number-of-queries=1000 --user=root") { |out,st| st == 0 }
  #      @servers.each do |server|
  #        result = server.spot_check_command("mysqlslap  --concurrency=5000 --iterations=10 --number-int-cols=2 --number-char-cols=3 --auto-generate-sql --csv=/tmp/mysqlslap_q1000_innodb.csv --engine=innodb --auto-generate-sql-add-autoincrement --auto-generate-sql-load-type=mixed --number-of-queries=1000 --user=root")
  #        raise "FATAL: mysqlslap check failed" unless result[:output].empty?
  #      end
  #    end
  
  #    def init_slave_from_slave_backup
  #     config_master_from_scratch(s_one)
  #     run_script("freeze_backups", s_one)
  #     wait_for_snapshots
  #     slave_init_server(s_two)
  #     run_script("backup", s_two)
  #      obj_behavior(s_two, :relaunch)
  #      s_one['dns-name'] = nil
  #      obj_behavior(s_two, :wait_for_operational_with_dns)
  #     wait_for_snapshots
  #      #sleep 300
  #     slave_init_server(s_two)
  #    end
  
  #    def run_promotion_operations
  #     config_master_from_scratch(s_one)
  #      obj_behavior(s_one, :relaunch)
  #      s_one.dns_name = nil
  #     wait_for_snapshots
  # need to wait for ebs snapshot, otherwise this could easily fail
  #     restore_server(s_two)
  #      obj_behavior(s_one, :wait_for_operational_with_dns)
  #     wait_for_snapshots
  #     slave_init_server(s_one)
  #     promote_server(s_one)
  #    end
  #
      def run_reboot_operations
  # Duplicate code here because we need to wait between the master and the slave time
        #reboot_all(true) # serially_reboot = true
        @servers.each do |s|
          obj_behavior(s, :reboot, true)
          obj_behavior(s, :wait_for_state, "operational")
        end
       wait_for_all("operational")
       run_reboot_checks
      end
  
      # This is where we perform multiple checks on the deployment after a reboot.
      def run_reboot_checks
        # one simple check we can do is the backup.  Backup can fail if anything is amiss
        @servers.each do |server|
         run_script("do_backup", server)
        end
      end
  
  #    def run_restore_with_timestamp_override
  #      obj_behavior(s_one, :relaunch)
  #      s_one.dns_name = nil
  #      obj_behavior(s_one, :wait_for_operational_with_dns)
  #     run_script('restore', s_one, { "OPT_DB_RESTORE_TIMESTAMP_OVERRIDE" => "text:#{find_snapshot_timestamp}" })
  #    end
  
  # Check for specific MySQL data.
      def check_mysql_monitoring
        mysql_plugins = [
                          {"plugin_name"=>"mysql", "plugin_type"=>"mysql_commands-delete"},
                          {"plugin_name"=>"mysql", "plugin_type"=>"mysql_commands-create_db"},
                          {"plugin_name"=>"mysql", "plugin_type"=>"mysql_commands-create_table"},
                          {"plugin_name"=>"mysql", "plugin_type"=>"mysql_commands-insert"},
                          {"plugin_name"=>"mysql", "plugin_type"=>"mysql_commands-show_databases"}
                        ]
        @servers.each do |server|
          unless server.multicloud
  #mysql commands to generate data for collectd to return
            for ii in 1...100
  #TODO: have to select db with every call.  figure a better way to do this and get rid of fast and ugly
  # cut and past hack.
             run_query("show databases", server)
             run_query("create database test#{ii}", server)
             run_query("use test#{ii}; create table test#{ii}(test text)", server)
             run_query("use test#{ii};show tables", server)
             run_query("use test#{ii};insert into test#{ii} values ('1')", server)
             run_query("use test#{ii};update test#{ii} set test='2'", server)
             run_query("use test#{ii};select * from test#{ii}", server)
             run_query("use test#{ii};delete from test#{ii}", server)
             run_query("show variables", server)
             run_query("show status", server)
             run_query("use test#{ii};grant select on test.* to root", server)
             run_query("use test#{ii};alter table test#{ii} rename to test2#{ii}", server)
            end
            mysql_plugins.each do |plugin|
              monitor = obj_behavior(server, :get_sketchy_data, { 'start' => -60,
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
  
  #    def create_master
  #     config_master_from_scratch(s_one)
  #    end
  
  #    def create_master_from_dumpfile
  #     config_master_from_scratch_from_dumpfile(s_one)
  #    end
  
    end
  end
end
