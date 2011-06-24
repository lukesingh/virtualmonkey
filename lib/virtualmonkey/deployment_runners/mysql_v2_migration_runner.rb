module VirtualMonkey
  module Runner
    class MysqlV2Migration
      include VirtualMonkey::Mixin::DeploymentBase
      include VirtualMonkey::Mixin::EBS
      include VirtualMonkey::Mixin::Mysql
      attr_accessor :scripts_to_run
      attr_accessor :db_ebs_prefix
  
      def s_one
        @servers.select { |s| s.nickname =~ /v2/ }.first
      end
  
      def s_two
        @servers.select { |s| s.nickname =~ /Database Manager/ }.first
      end
  
      def run_promotion_operations
        config_master_from_scratch(s_one)
        s_one.relaunch
        s_one.dns_name = nil
        wait_for_snapshots
      end
  
      # lookup all the RightScripts that we will want to run
      def mysql_v2_migration_lookup_scripts
  #TODO fix this so epoch is not hard coded.
  puts "WE ARE HARDCODING THE TOOL BOX NAMES TO USE 11H1.b1"
       scripts = [
                   [ 'restore', 'restore and become' ],
                   [ 'slave_init', 'slave init' ],
                   [ 'promote', 'EBS promote to master' ],
                   [ 'backup', 'EBS backup' ],
                   [ 'terminate', 'TERMINATE SERVER' ]
                 ]
        ebs_toolbox_scripts = [
                                [ 'create_stripe' , 'EBS stripe volume create' ]
                              ]
        mysql_toolbox_scripts = [
                                [ 'create_mysql_ebs_stripe' , 'DB Create MySQL EBS stripe volume' ],
                                [ 'create_migrate_script' , 'DB EBS create migrate script from MySQL EBS v1' ]
                              ]
        raise "FATAL: Need 2 MySQL servers in the deployment" unless @servers.size == 2
  
        # Use the HEAD revision.
        ebs_tbx = ServerTemplate.find_by(:nickname) { |n| n =~ /EBS Stripe Toolbox - 11H1/ }.first
        raise "Did not find ebs toolbox template" unless ebs_tbx
  
        puts "TODO: USING MySQL 5.0 toolbox (should account for differences between 5.0/5.1)" #<--- TODO
        db_tbx = ServerTemplate.find_by(:nickname) { |n| n =~ /Database Manager with MySQL 5.0 Toolbox - 11H1/ }.first
        raise "Did not find mysql toolbox template" unless db_tbx
  
        st_dbm = ServerTemplate.find(resource_id(s_two.server_template_href))
        load_script_table(st_dbm,scripts,st_dbm)
        load_script_table(ebs_tbx,ebs_toolbox_scripts,st_dbm)
        load_script_table(db_tbx,mysql_toolbox_scripts,st_dbm)
  
        # st_v2
        ebs_tbx = ServerTemplate.find_by(:nickname) { |n| n =~ /MySQL EBS Stripe Toolbox v2/ }.first
        raise "Did not find ebs toolbox template" unless ebs_tbx
  
        puts "TODO: USING MySQL 5.0 toolbox (should account for differences between 5.0/5.1)" #<--- TODO
        db_tbx = ServerTemplate.find_by(:nickname) { |n| n =~ /MySQL 5.0 Stripe Toolbox v5/ }.first
        raise "Did not find mysql toolbox template" unless db_tbx
  
        st_v2 = ServerTemplate.find(resource_id(s_one.server_template_href))
        load_script_table(st_v2,scripts,st_v2)
        load_script_table(ebs_tbx,ebs_toolbox_scripts,st_v2)
        load_script_table(db_tbx,mysql_toolbox_scripts,st_v2)
  
        # hardwired script! (this is an 'anyscript' that users typically use to setup the master dns)
        # This a special version of the register that uses MASTER_DB_DNSID instead of a test DNSID
        # This is identical to "DB register master" However it is not part of the template.
        load_script('master_init', RightScript.new('href' => "/api/acct/2901/right_scripts/195053"))
        raise "Did not find script" unless script_to_run?('master_init')
      end
  
      def launch_db_manager_slave
        s_two.settings
        wait_for_snapshots
        run_script("slave_init", s_two)
      end
    end
  end
end
