module VirtualMonkey
  module Runner
    class Jenkins
      include VirtualMonkey::Mixin::DeploymentBase
      include VirtualMonkey::Mixin::Jenkins
      def lookup_scripts
        scripts = [
                   [ 'do_force_reset', 'block_device::do_force_reset' ],
                   [ 'setup_block_device', 'block_device::setup_block_device' ],
                   [ 'service_restart', 'Jenkins \(re\)start' ],
                   [ 'service_stop', 'Jenkins stop' ],
                   [ 'backup', 'Jenkins backup' ],
                   [ 'restore', 'Jenkins restore' ],
                   [ 'move_datadir', 'Jenkins move datadir' ],
                   [ 'setup_backups', 'Jenkins setup continuous' ]
                  ]
        st = ServerTemplate.find(resource_id(s_one.server_template_href))
        load_script_table(st,scripts)
      end
    end
  end
end
