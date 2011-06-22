module VirtualMonkey
  module Runner
    class MysqlToolbox
      include VirtualMonkey::Mixin::DeploymentBase
      include VirtualMonkey::Mixin::EBS
      include VirtualMonkey::Mixin::Mysql
      attr_accessor :scripts_to_run
  
      def mysql_toolbox_lookup_scripts
        scripts_mysql = [
                           [ 'promote', 'EBS promote to master' ],
                           [ 'backup', 'EBS backup' ],
                           [ 'terminate', 'TERMINATE SERVER' ]
                         ]
        scripts_my_toolbox = [
                                [ 'create_backup_scripts', 'EBS create backup scripts' ],
                                [ 'enable_network', 'DB MySQL Enable Networking' ],
                                [ 'create_migrate_script', 'DB EBS create migrate script from MySQL EBS v1' ],
                                [ 'create_mysql_ebs_stripe', 'DB Create MySQL EBS stripe' ],
                                [ 'grow_volume', 'DB EBS slave init and grow stripe volume' ],
                                [ 'restore', 'DB EBS restore stripe volume' ]
                              ]
        #TODO - this is hardcoded for 5.0 toolbox - need to deal with issue that we have two
        #toolboxes and their names are going to change
        # Use the HEAD revision.
        tbx = ServerTemplate.find_by(:nickname) { |n| n =~ /Database Manager with MySQL 5.0 Toolbox - 11H1/ }.first
        raise "FATAL: could not find toolbox" unless tbx
        st = ServerTemplate.find(resource_id(s_one.server_template_href))
        load_script_table(st,scripts_mysql)
        load_script_table(tbx,scripts_my_toolbox)
        # hardwired script! (this is an 'anyscript' that users typically use to setup the master dns)
        # This a special version of the register that uses MASTER_DB_DNSID instead of a test DNSID
        # This is identical to "DB register master" However it is not part of the template.
        load_script('master_init', RightScript.new('href' => "/api/acct/2901/right_scripts/195053"))
        raise "Did not find script" unless script_to_run?('master_init')
      end
    end
  end
end
