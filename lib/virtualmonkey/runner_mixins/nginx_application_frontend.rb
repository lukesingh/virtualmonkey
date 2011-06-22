module VirtualMonkey
  module Mixin
    module NginxApplicationFrontend
      include VirtualMonkey::Mixin::Frontend
      include VirtualMonkey::Mixin::Application
      include VirtualMonkey::Mixin::UnifiedApplication
      include VirtualMonkey::Mixin::ApplicationFrontend
  
      def log_rotation_checks
        detect_os
  
        fe_servers.each do |server|
          behavior(:force_log_rotation, server)
          behavior(:log_check, server, "/var/log/nginx/*access.log.1*")
        end
      end
  
      def frontend_checks
        behavior(:detect_os)
  
        behavior(:run_unified_application_checks, fe_servers, 80)
  
        # check that all application servers exist in the Nginx config file on all fe_servers
        server_ips = Array.new
        app_servers.each { |app| server_ips << app['private-ip-address'] }
        fe_servers.each do |fe|
          fe.settings
          nginx_config = obj_behavior(fe, :spot_check_command, 'flock -n /etc/nginx/sites-enabled/lb -c "grep -E ^server /etc/nginx/sites-enabled/lb"')
          puts "INFO: flock status was #{nginx_config[:status]}"
          server_ips.each do |ip|
            if nginx_config.to_s.include?(ip) == false
              puts nginx_config[:output]
              raise "FATAL: Nginx config did not contain server ip #{ip}"
            end
          end
        end
  
        # restart Nginx and check that it succeeds
        run_script_on_set('nginx_restart', fe_servers, true)
        fe_servers.each_with_index do |server,i|
          response = nil
          count = 0
          until response || count > 3 do
            response = obj_behavior(server, :spot_check_command?, "service nginx status")
            break if response
            count += 1
            sleep 10
          end
          raise "Nginx status failed" unless response
        end
  
      end
  
      def frontend_lookup_scripts
        fe_scripts = [
                      [ 'nginx_restart', 'WEB Nginx.* \(re\)start' ]
                     ]
        app_scripts = [
                       [ 'connect', 'LB Application to Nginx connect' ]
                      ]
        st = ServerTemplate.find(resource_id(fe_servers.first.server_template_href))
        load_script_table(st,fe_scripts)
        st = ServerTemplate.find(resource_id(app_servers.first.server_template_href))
        load_script_table(st,app_scripts)
      end
    end
  end
end
