module VirtualMonkey
  module Runner
    class Postgres
      include VirtualMonkey::Mixin::DeploymentBase
      include VirtualMonkey::Mixin::EBS
      include VirtualMonkey::Mixin::Postgres
      attr_accessor :scripts_to_run
      attr_accessor :db_ebs_prefix
  
      # lookup all the RightScripts that we will want to run
      def lookup_scripts
       scripts = [
                   [ 'backup', 'EBS PostgreSQL backup' ],
                   [ 'create_stripe' , 'Create PostgreSQL EBS stripe volume' ],
                   [ 'dump_import', 'PostgreSQL dump import'],
                   [ 'dump_export', 'PostgreSQL dump export'],
                   [ 'freeze_backups', 'DB PostgreSQL Freeze' ],
                   [ 'monitor_add', 'PostgreSQL Add DB monitoring' ],
                   [ 'promote', 'DB EBS PostgreSQL promote to master' ],
                   [ 'restore', 'PostgreSQL restore and become' ],
                   [ 'slave_init', 'DB EBS PostgreSQL slave init -' ],
                   [ 'grow_volume', 'DB EBS PostgreSQL slave init and grow stripe volume' ],
                   [ 'terminate', 'PostgreSQL TERMINATE SERVER' ],
                   [ 'unfreeze_backups', 'DB PostgreSQL Unfreeze' ]
                 ]
  
        st = ServerTemplate.find(resource_id(s_one.server_template_href))
        load_script_table(st,scripts)
        # hardwired script! (this is an 'anyscript' that users typically use to setup the master dns)
        # This a special version of the register that uses MASTER_DB_DNSID instead of a test DNSID
        # This is identical to "DB register master" However it is not part of the template.
        load_script('master_init', RightScript.new('href' => "/api/acct/2901/right_scripts/195053"))
        raise "Did not find script" unless script_to_run?('master_init')
      end
    end
  end
end
