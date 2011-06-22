module VirtualMonkey
  module Runner
    class SimpleWindowsNet
      include VirtualMonkey::Mixin::DeploymentBase
      include VirtualMonkey::Mixin::SimpleWindows
  
      def simple_windows_net_aio_lookup_scripts
       scripts = [
                   [ 'backup', 'backup' ],
                   [ 'restore', 'restore' ],
                   [ 'backup_to_s3', 'backup_to_s3' ],
                   [ 'create_scheduled_task', 'create_scheduled_task' ],
                   [ 'delete_scheduled_task', 'delete_scheduled_task' ],
                   [ 'register_with_elb', 'register_with_elb' ],
                   [ 'deregister_from_elb', 'deregister_from_elb' ],
                   [ 'update_code_svn', 'update_code_svn' ]
                 ]
        st = ServerTemplate.find(resource_id(s_one.server_template_href))
        load_script_table(st,scripts)
        load_script('backup_database_check', RightScript.new('href' => "/api/acct/2901/right_scripts/310407"))
        raise "Did not find script" unless script_to_run?('backup_database_check')
      end
    end
  end
end
