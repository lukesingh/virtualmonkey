module VirtualMonkey
  module Runner
    class SimpleWindowsBlog
      include VirtualMonkey::Mixin::DeploymentBase
      include VirtualMonkey::Mixin::SimpleWindows
  
      def simple_windows_blog_lookup_scripts
       scripts = [
                   [ 'backup_database', 'backup_database' ],
                   [ 'drop_database', 'drop_database' ],
                   [ 'restore_database', 'restore_database' ],
                 ]
        st = ServerTemplate.find(resource_id(s_one.server_template_href))
        load_script_table(st,scripts)
        load_script('backup_database_check', RightScript.new('href' => "/api/acct/2901/right_scripts/310407"))
      end
    end
  end
end 
