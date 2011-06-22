module VirtualMonkey
  module Runner
    class SimpleWindowsSQL
      include VirtualMonkey::Mixin::DeploymentBase
      include VirtualMonkey::Mixin::SimpleWindows
  
      def server_sql2005
          @servers.select { |s| s.nickname =~ /Database/i }.first
      end
  
      def oleg_windows_sql_lookup_scripts
       scripts = [
                   [ 'EBS Restore data and log volumes', 'EBS Restore data and log volumes' ],
                   [ 'EBS Create data and log volumes', 'EBS Create data and log volumes' ],
                   [ 'DB SQLS Configure tempdb', 'DB SQLS Configure tempdb' ],
                   [ 'EBS Backup data and log volumes', 'EBS Backup data and log volumes' ],
                   [ 'DB SQLS Rename instance', 'DB SQLS Rename instance' ],
                   [ 'DB SQLS create user', 'DB SQLS create user' ],
                   [ 'DB SQLS DISABLE SERVER - snapshot, detach and delete volumes', 'DB SQLS DISABLE SERVER - snapshot, detach and delete volumes' ],
                   [ 'DB SQLS Repair log files', 'DB SQLS Repair log files' ],
                 ]
        st = ServerTemplate.find(resource_id(server_sql2005.server_template_href))
        load_script_table(st,scripts)
        load_script('sql_db_check', RightScript.new('href' => "/api/acct/2901/right_scripts/335104"))
        load_script('load_db', RightScript.new('href' => "/api/acct/2901/right_scripts/331394"))
        load_script('tempdb_check', RightScript.new('href' => "/api/acct/2901/right_scripts/381500"))
        load_script('newuser_check', RightScript.new('href' => "/api/acct/2901/right_scripts/381571"))
        load_script('log_repair_before', RightScript.new('href' => "/api/acct/2901/right_scripts/381785"))
        load_script('log_repair_after', RightScript.new('href' => "/api/acct/2901/right_scripts/382117"))
        load_script('new_name_check', RightScript.new('href' => "/api/acct/2901/right_scripts/382185"))
      end
    end
  end
end
