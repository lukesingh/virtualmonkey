module VirtualMonkey
  module Runner
    class EBS
      include VirtualMonkey::Mixin::DeploymentBase
      include VirtualMonkey::Mixin::EBS

      # lookup all the RightScripts that we will want to run
      def lookup_scripts
        scripts = [
                   [ 'backup', 'EBS stripe volume backup' ],
                   [ 'restore', 'EBS stripe volume restore' ],
                   [ 'continuous_backup', 'EBS continuous backups' ],
                   [ 'unfreeze', 'EBS unfreeze volume backups' ],
                   [ 'freeze', 'EBS freeze volume backups' ],
                   [ 'create_stripe', 'EBS stripe volume create' ],
                   [ 'create_backup_scripts', 'EBS create backup scripts' ],
                   [ 'grow_volume', 'EBS stripe volume grow and restore' ],
                   [ 'terminate', 'TERMINATE' ]
                 ]
        st = ServerTemplate.find(resource_id(s_one.server_template_href))
        load_script_table(st,scripts)
      end
    end
  end
end
