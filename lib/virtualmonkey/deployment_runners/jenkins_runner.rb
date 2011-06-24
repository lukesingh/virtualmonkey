module VirtualMonkey
  module Runner
    class Jenkins
      include VirtualMonkey::Mixin::DeploymentBase
      include VirtualMonkey::Mixin::Jenkins
      def jenkins_lookup_scripts
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
        st = match_st_by_server(s_one)
        load_script_table(st,scripts)
      end
    end
  end
end
