module VirtualMonkey
  module Mixin
    module ApplicationFrontend
      include VirtualMonkey::Mixin::Application
      include VirtualMonkey::Mixin::Frontend
      include VirtualMonkey::Mixin::UnifiedApplication
      
      # a custom startup sequence is required for fe/app deployments (inputs workaround)
      def startup_sequence
        launch_set(fe_servers)
        wait_for_set(fe_servers, "operational")
        
        set_lb_hostname
  
        launch_set(app_servers)
        wait_for_set(app_servers, "operational")
      end
  
      def run_reboot_operations
       reboot_all(true)
       run_reboot_checks
      end
  
      def run_reboot_checks
       run_unified_application_checks(fe_servers, 80)
       run_unified_application_checks(app_servers)
      end
      
      def log_rotation_checks
        # this works for php, TODO: rails
        #app_servers.each do |server|
        #  force_log_rotation(server)
        #  log_check(server,"/mnt/log/#{server.apache_str}/access.log.1")
        #end
       detect_os
  
        fe_servers.each do |server|
         force_log_rotation(server)
         log_check(server, "/mnt/log/#{server.apache_str}/haproxy.log.1")
        end
      end
      
    end
  end
end
