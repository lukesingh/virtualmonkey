module VirtualMonkey
  module Mixin
    module Frontend
   
      #require File.expand_path(File.dirname(__FILE__), "application")
    
      # returns an Array of the Front End servers in the deployment
      def fe_servers
        res = @servers.select { |s| s.nickname =~ /Front End/ || s.nickname =~ /FrontEnd/ || s.nickname =~ /Apache with HAproxy/ || s.nickname =~ /Load Balancer/ }
        raise "FATAL: No frontend servers found" unless res.length > 0
        res
      end
  
      # returns String with all the private dns of the Front End servers
      # used for setting the LB_HOSTNAME input.
      def get_lb_hostname_input
        lb_hostname_input = "text:"
        fe_servers.each do |fe|
          timeout = 30
          loopcounter = 0
          begin
            if fe.settings['private-dns-name'] == nil
              raise "FATAL: private DNS name is empty" if loopcounter > 10
              sleep(timeout)
              loopcounter += 1
              next
            end
            lb_hostname_input << fe.settings['private-dns-name'] + " "
            done = true
          end while !done
        end
        lb_hostname_input
      end
  
      def frontend_checks
        behavior(:detect_os)
  
        behavior(:run_unified_application_checks, fe_servers, 80)
  
        # check that all application servers exist in the haproxy config file on all fe_servers
        server_ips = Array.new
        app_servers.each { |app| server_ips << app['private-ip-address'] }
        fe_servers.each do |fe|
          fe.settings
          haproxy_config = obj_behavior(fe, :spot_check_command, 'flock -n /home/haproxy/rightscale_lb.cfg -c "cat /home/haproxy/rightscale_lb.cfg | grep server"')
          puts "INFO: flock status was #{haproxy_config[:status]}"
          server_ips.each do |ip|
            if haproxy_config.to_s.include?(ip) == false
              puts haproxy_config[:output]
              raise "FATAL: haproxy config did not contain server ip #{ip}"
            end
          end
        end
  
        # restart haproxy and check that it succeeds
        fe_servers.each_with_index do |server,i|
          response = probe(server, 'service haproxy stop')
          raise "Haproxy stop command failed" unless response
  
          stopped = false
          count = 0
          until response || count > 3 do
            response = obj_behavior(server, :spot_check_command, server.haproxy_check)
            stopped = response.include?("not running")
            break if stopped
            count += 1
            sleep 10
          end
  
          response = probe(server, 'service haproxy start')
          raise "Haproxy start failed" unless response
        end
  
        # restart apache and check that it succeeds
        behavior(:run_script_on_set, 'apache_restart', fe_servers, true)
        fe_servers.each_with_index do |server,i|
          response = nil
          count = 0
          until response || count > 3 do
            response = probe(server, server.apache_check)
            break if response	
            count += 1
            sleep 10
          end
          raise "Apache status failed" unless response
        end
        
      end
  
      def cross_connect_frontends
        options = { :LB_HOSTNAME => behavior(:get_lb_hostname_input) }
        behavior(:run_script_on_set, 'connect', fe_servers, true, options)
      end
  
      def setup_https_vhost
        behavior(:run_script_on_set, fe_servers, 'https_vhost')
        fe_servers.each_with_index do |server,i|
          behavior(:test_http_response, "html serving succeeded", "https://" + server.dns_name + "/index.html", "443")
        end
      end
  
      def frontend_lookup_scripts
        fe_scripts = [
                      [ 'apache_restart', 'WEB apache \(re\)start' ],
  		    [ 'https_vhost', 'WEB apache FrontEnd https vhost' ]
                     ]
        app_scripts = [
                       [ 'connect', 'LB [app|application|mongrels]+ to HA[ pP]+roxy connect' ]
                      ]
        st = ServerTemplate.find(resource_id(fe_servers.first.server_template_href))
        load_script_table(st,fe_scripts)
        st = ServerTemplate.find(resource_id(app_servers.first.server_template_href))
        load_script_table(st,app_scripts)
      end 
  
  
      # Run spot checks for FE servers in the deployment
      def run_fe_tests
      end
  
      # Special startup sequence for an FE deployment
      def startup
      end
  
    end
  end
end
