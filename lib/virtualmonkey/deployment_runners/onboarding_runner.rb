module VirtualMonkey
  module Runner
    class Onboarding
      include VirtualMonkey::Mixin::DeploymentBase
      include VirtualMonkey::Mixin::UnifiedApplication
      include VirtualMonkey::Mixin::Mysql
  
      def run_onboarding_checks
        # check that the standard unified app is responding on port 80
        @servers.each do |server| 
          url_base = "#{server.dns_name}:#{80}"
          behavior(:test_http_response, "Congratulations", "#{url_base}", 80)
        end
      end
  
  # Check for specific passenger data.
      def check_passenger_monitoring
        passenger_plugins = [
                          {"plugin_name"=>"passenger", "plugin_type"=>"passenger_instances","field"=>"value"},
                          {"plugin_name"=>"passenger", "plugin_type"=>"passenger_processes","field"=>"max"},
                          {"plugin_name"=>"passenger", "plugin_type"=>"passenger_queued","field"=>"value"},
                          {"plugin_name"=>"passenger", "plugin_type"=>"passenger_requests","field"=>"value"}
                        ]
        sleep 60 # wait for some data to be available
        @servers.each do |server|
          unless server.multicloud
  #passenger commands to generate data for collectd to return
  #          for ii in 1...100
  #            # how do we force there to be data??  For now just check that the graph exists - cause the
  #            # bug was missing graphs.
  #          end
            passenger_plugins.each do |plugin|
              monitor = obj_behavior(server, :get_sketchy_data, {'start' => -60,
                                                                 'end' => -20,
                                                                 'plugin_name' => plugin['plugin_name'],
                                                                 'plugin_type' => plugin['plugin_type']})
              value = monitor['data']["#{plugin['field']}"]
              puts "Checking #{plugin['plugin_name']}-#{plugin['plugin_type']}: value #{value}"
              raise "No #{plugin['plugin_name']}-#{plugin['plugin_type']} data" unless value.length > 0
  #            # Need to check for that there is at least one non 0 value returned.
  #            for nn in 0...value.length
  #              if value[nn] > 0
  #                break
  #              end
  #            end
  #            raise "No #{plugin['plugin_name']}-#{plugin['plugin_type']} time" unless nn < value.length
              puts "Monitoring is OK for #{plugin['plugin_name']}-#{plugin['plugin_type']}"
            end
          end
        end
      end
    end
  end
end
