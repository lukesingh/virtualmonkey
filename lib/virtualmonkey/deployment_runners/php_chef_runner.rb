module VirtualMonkey
  module Runner
    class PhpChef
      include VirtualMonkey::Mixin::DeploymentBase
      include VirtualMonkey::Mixin::ApplicationFrontend
  
      def set_lb_hostname
        @deployment.set_input("lb_haproxy/host", get_lb_hostname_input)
      end
  
      # sets the MASTER_DB_DNSNAME to this machine's ip address
      def set_master_db_dnsname
        the_name = get_tester_ip_addr
        @deployment.set_input("php/db_dns_name", the_name) 
      end
   
      def frontend_checks
        detect_os
  
        run_unified_application_checks(fe_servers, 80)
  
        # check that all application servers exist in the haproxy config file on all fe_servers
        server_ips = Array.new
        app_servers.each { |app| server_ips << app['private-ip-address'] }
        fe_servers.each do |fe|
          fe.settings
          haproxy_config = fe.spot_check_command('cat /home/haproxy/rightscale_lb.cfg | grep server')
          server_ips.each { |ip|  haproxy_config.to_s.include?(ip).should == true }
        end
  
        # restart haproxy and check that it succeeds
        fe_servers.each_with_index do |server,i|
          response = server.spot_check_command?('service haproxy stop')
          raise "Haproxy stop command failed" unless response
  
          stopped = false
          count = 0
          until response || count > 3 do
            response = server.spot_check_command(server.haproxy_check)
            stopped = response.include?("not running")
            break if stopped
            count += 1
            sleep 10
          end
  
          response = server.spot_check_command?('service haproxy start')
          raise "Haproxy start failed" unless response
        end
      end
  
      def php_chef_lookup_scripts
        recipes = [
                    [ 'attach', 'lb_haproxy::do_attach_request' ]
                  ]
        fe_st = ServerTemplate.find(resource_id(fe_servers.first.server_template_href))
        load_script_table(fe_st,recipes)
      end
  
      def cross_connect_frontends
        run_script_on_all('attach')
      end
      
    end
  end
end
