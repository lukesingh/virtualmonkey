module VirtualMonkey
  module Runner
    class MysqlChef
      include VirtualMonkey::Mixin::DeploymentBase
      include VirtualMonkey::Mixin::ChefEBS
      include VirtualMonkey::Mixin::ChefMysql
      include VirtualMonkey::Mixin::Chef
      attr_accessor :scripts_to_run
      attr_accessor :db_ebs_prefix
  
      # lookup all the RightScripts that we will want to run
      def mysql_lookup_scripts
       scripts = [
                   [ 'setup_block_device', 'db_mysql::setup_block_device' ],
                   [ 'do_backup', 'db_mysql::do_backup' ],
                   [ 'do_restore', 'db_mysql::do_restore' ],
                   [ 'do_backup_s3', 'db_mysql::do_backup_s3' ],
                   [ 'do_backup_ebs', 'db_mysql::do_backup_ebs' ],
                   [ 'do_backup_cloud_files', 'db_mysql::do_backup_cloud_files' ],
                   [ 'do_restore_s3', 'db_mysql::do_restore_s3' ],
                   [ 'do_restore_ebs', 'db_mysql::do_restore_ebs' ],
                   [ 'do_restore_cloud_files', 'db_mysql::do_restore_cloud_files' ],
                   [ 'do_restore_cloud_files', 'db_mysql::do_restore_cloud_files' ],
                   [ 'do_force_reset', 'db_mysql::do_force_reset' ]
                 ]
        raise "FATAL: Need 1 MySQL servers in the deployment" unless @servers.size == 1
  
        st = ServerTemplate.find(resource_id(s_one.server_template_href))
        load_script_table(st,scripts)
      end
    end
  end
end
