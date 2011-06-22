module VirtualMonkey
  module Runner
    class Mysql
      include VirtualMonkey::Mixin::DeploymentBase
      include VirtualMonkey::Mixin::EBS
      include VirtualMonkey::Mixin::Mysql
      attr_accessor :scripts_to_run
      attr_accessor :db_ebs_prefix
  
      # lookup all the RightScripts that we will want to run
      def mysql_lookup_scripts
  #TODO fix this so epoch is not hard coded.
  puts "WE ARE HARDCODING THE TOOL BOX NAMES TO USE 11H1"
       scripts = [
                   [ 'restore', 'restore and become' ],
                   [ 'slave_init', 'slave init' ],
                   [ 'promote', 'EBS promote to master' ],
                   [ 'backup', 'EBS backup' ],
                   [ 'terminate', 'TERMINATE SERVER' ],
                   [ 'freeze_backups', 'DB freeze' ]
                 ]
        ebs_toolbox_scripts = [
                                [ 'create_stripe' , 'EBS stripe volume create - 11H1' ]
                              ]
        mysql_toolbox_scripts = [
                                [ 'create_mysql_ebs_stripe' , 'DB Create MySQL EBS stripe volume - 11H1' ],
                                [ 'create_migrate_script' , 'DB EBS create migrate script from MySQL EBS v1' ]
                              ]
        raise "FATAL: Need 2 MySQL servers in the deployment" unless @servers.size == 2
  
        # Use the HEAD revision.
        ebs_tbx = ServerTemplate.find_by(:nickname) { |n| n =~ /EBS Stripe Toolbox - 11H1/ }.select { |st| st.is_head_version }.first
        raise "Did not find ebs toolbox template" unless ebs_tbx
  
        db_tbx = ServerTemplate.find 84657
        raise "Did not find mysql toolbox template" unless db_tbx
        puts "USING Toolbox Template: #{db_tbx.nickname}"
  
        st = ServerTemplate.find(resource_id(s_one.server_template_href))
        load_script_table(st,scripts)
        load_script_table(ebs_tbx,ebs_toolbox_scripts)
        load_script_table(db_tbx,mysql_toolbox_scripts)
        # hardwired script! (this is an 'anyscript' that users typically use to setup the master dns)
        # This a special version of the register that uses MASTER_DB_DNSID instead of a test DNSID
        # This is identical to "DB register master" However it is not part of the template.
        load_script('master_init', RightScript.new('href' => "/api/acct/2901/right_scripts/195053"))
        raise "Did not find script" unless script_to_run?('master_init')
      end
  
    end
  end
end
