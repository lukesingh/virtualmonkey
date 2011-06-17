module VirtualMonkey
  module DeploymentBase
    include VirtualMonkey::TestCaseInterface
    attr_accessor :deployment, :servers, :server_templates
    attr_accessor :scripts_to_run
    
    def initialize(deployment)
      test_case_interface_init()
      @scripts_to_run = {}
      @server_templates = []
      @deployment = Deployment.find_by_nickname_speed(deployment).first
      raise "Fatal: Could not find a deployment named #{deployment}" unless @deployment
      populate_settings
    end

    # Ensures the following blacklist entries are entered for all runners
    def deployment_base_blacklist
      [
        ["/var/log/messages", ".*", "exception"],
        ["/var/log/messages", ".*", "error"],
        ["/var/log/messages", ".*", "fatal"],
        ["/var/log/messages", ".*", "fail"],
        ["/var/log/messages", ".*", "missing"],
        ["/var/log/messages", ".*", "BEGIN RSA PRIVATE KEY"]
      ]
    end

    # Ensures the following whitelist entries are entered for all runners
    def deployment_base_whitelist
      [
        ["/var/log/messages", ".*", "destination\(d_httperror\)=0"]
      ]
    end

    # Makes this exception_handle available for all runners
    def deployment_base_exception_handle(e)
      if e.message =~ /Insufficient capacity/ and @retry_loop.last < 10
        puts "Got \"Insufficient capacity\". Retrying...."
        sleep 60
        incr_retry_loop
        return true # Exception Handled
      elsif e.message =~ /Service Temporarily Unavailable/ and @retry_loop.last < 30
        puts "Got \"Service Temporarily Unavailable\". Retrying...."
        sleep 10
        incr_retry_loop
        return true # Exception Handled
      else
        return false
      end
    end

    # Master method that calls all methods with "lookup_scripts" in their name
    def __lookup_scripts__
      all_methods = self.methods + self.private_methods
      lookup_script_methods = all_methods.select { |m| m =~ /lookup_scripts/ and m != "__lookup_scripts__" }
      lookup_script_methods.each { |method_name| self.__send__(method_name) }
    end

    # Returns the API 1.0 integer id of the rest_connection object or href
    def resource_id(res)
      if res.is_a?(String)
        return res.split(/\//).last.to_i
      else
        return res.href.split(/\//).last.to_i
      end
    end

    # Loads a table of [friendly_name, script/recipe regex] from reference_template, attaching them to all templates in the deployment unless add_only_to_this_st is set
    def load_script_table(reference_template, table, add_only_to_this_st = nil)
      if add_only_to_this_st.is_a?(ServerInterface) or add_only_to_this_st.is_a?(Server)
        sts = [ ServerTemplate.find(resource_id(add_only_to_this_st.server_template_href)) ]
      elsif add_only_to_this_st.is_a?(ServerTemplate)
        sts = [ add_only_to_this_st ]
      elsif add_only_to_this_st.nil?
        sts = @server_templates
      end
      sts.each { |st|
        table.each { |a|
          st_id = resource_id(st)
          puts "WARNING: Overwriting '#{a[0]}' for ServerTemplate #{st.nickname}" if @scripts_to_run[st_id]
          @scripts_to_run[st_id] = {} unless @scripts_to_run[st_id]
          @scripts_to_run[st_id][ a[0] ] = reference_template.executables.detect { |ex| ex.name =~ /#{a[1]}/i or ex.recipe =~ /#{a[1]}/i }
          raise "FATAL: Script #{a[1]} not found for #{st.nickname}" unless @scripts_to_run[st_id][ a[0] ]
        }
      }
    end

    # Determines which logs to run for the available server_templates, then does the message check
    def run_logger_audit(interactive = false, strict = false)
      ret_string = ""
      mc = MessageCheck.new(@log_checklists, strict)
      logs = obj_behavior(mc, :logs_to_check, @server_templates)
      logs.each do |st_href,logfile_array|
        servers_to_check = @servers.select { |s| s.server_template_href == st_href }
        logfile_array.each { |logfile| ret_string += obj_behavior(mc, :check_messages, servers_to_check, interactive, logfile) }
      end
      if ret_string =~ /ERROR/
        raise ret_string
      else
        return ret_string
      end
    end

    # Loads a single hard-coded RightScript or Recipe, attaching it to all templates in the deployment unless add_only_to_this_st is set
    def load_script(friendly_name, script, add_only_to_this_st=nil)
      if add_only_to_this_st.is_a?(ServerInterface) or add_only_to_this_st.is_a?(Server)
        sts = [ ServerTemplate.find(resource_id(add_only_to_this_st.server_template_href)) ]
      elsif add_only_to_this_st.is_a?(ServerTemplate)
        sts = [ add_only_to_this_st ]
      elsif add_only_to_this_st.nil?
        sts = @server_templates
      end
      sts.each { |st|
        @scripts_to_run[resource_id(st)] = {} unless @scripts_to_run[resource_id(st)]
        @scripts_to_run[resource_id(st)][friendly_name] = script
        raise "FATAL: Script #{a[1]} not found" unless @scripts_to_run[resource_id(st)][friendly_name]
      }
    end

    def s_one
      @servers[0]
    end

    def s_two
      @servers[1]
    end

    def s_three
      @servers[2]
    end

    def s_four
      @servers[3]
    end

    # Launch all servers in the deployment.
    def launch_all
      @servers.each { |s|
        begin
          obj_behavior(s, :start)
        rescue Exception => e
          raise e unless e.message =~ /AlreadyLaunchedError/
        end
      }
    end

    # sets the MASTER_DB_DNSNAME to this machine's ip address
    def set_master_db_dnsname
      the_name = get_tester_ip_addr
      obj_behavior(@deployment, :set_input, "MASTER_DB_DNSNAME", the_name) 
      obj_behavior(@deployment, :set_input, "DB_HOST_NAME", the_name) 
    end

    # sets the db_mysql/fqdn to this machine's ip address
    def set_chef_master_db_dnsname
      the_name = get_tester_ip_addr
      obj_behavior(@deployment, :set_input, "db_mysql/fqdn", the_name) 
    end

    # Launch server(s) that match nickname_substr
    # * nickname_substr<~String> - regex compatible string to match
    def launch_set(nickname_substr)
      set = select_set(nickname_substr)  
      set.each { |s|
        begin
          obj_behavior(s, :start)
        rescue Exception => e
          raise e unless e.message =~ /AlreadyLaunchedError/
        end
      }
    end

    # Re-Launch all server
    def relaunch_all
      @servers.each { |s|
        begin
          obj_behavior(s, :relaunch)
        rescue Exception => e
          raise e #unless e.message =~ /AlreadyLaunchedError/
        end
      }
    end

    # un-set all tags on all servers in the deployment
    def unset_all_tags
      @servers.each do |s|
        # can't unset ALL tags, so we must set a bogus one
        s.tags = [{"name"=>"removeme:now=1"}]
        obj_behavior(s, :save)
      end
    end

    # Wait for server(s) matching nickname_substr to enter state
    # * nickname_substr<~String> - regex compatible string to match
    # * state<~String> - state to wait for, eg. operational
    def wait_for_set(nickname_substr, state, timeout=1200)
      set = select_set(nickname_substr)  
      state_wait(set, state, timeout)
    end

    # Helper method, waits for state on a set of servers.
    # * set<~Array> of servers to operate on
    # * state<~String> state to wait for
    def state_wait(set, state, timeout=1200)
      # do a special wait, if waiting for operational (for dns)
      if state == "operational"
        set.each { |server| obj_behavior(server, :wait_for_operational_with_dns, timeout) }
      else
        set.each { |server| obj_behavior(server, :wait_for_state, state, timeout) }
      end
    end
    
    # Wait for all server(s) to enter state.
    # * state<~String> - state to wait for, eg. operational
    def wait_for_all(state, timeout=1200)
      state_wait(@servers, state, timeout)
    end

    def start_ebs_all(wait=true)
      @servers.each { |s| obj_behavior(s, :start_ebs) }
      wait_for_all("operational") if wait
      @servers.each { |s| 
        s.dns_name = nil 
        s.private_dns_name = nil
      }
    end

    def stop_ebs_all(wait=true)
      @servers.each { |s| obj_behavior(s, :stop_ebs) }
      wait_for_all("stopped") if wait
      @servers.each { |s| 
        s.dns_name = nil 
        s.private_dns_name = nil
      }
    end

    def stop_all(wait=true)
      @servers.each { |s| obj_behavior(s, :stop) }
      wait_for_all("stopped") if wait
      @servers.each { |s| 
        s.dns_name = nil 
        s.private_dns_name = nil
      }
    end

    def reboot_all(serially_reboot = false)
      wait_for_reboot = true
      # Do NOT thread this each statement
      @servers.each do |s| 
        obj_behavior(s, :reboot, wait_for_reboot)
        if serially_reboot
          obj_behavior(s, :wait_for_state, "operational")
        end
      end
      @servers.each do |s| 
        obj_behavior(s, :wait_for_state, "operational")
      end
    end

    # Run a script on all servers in the deployment in parallel
    def run_script_on_all(friendly_name, wait = true, options = nil)
      run_script_on_set(friendly_name, @servers, wait, options)
    end

    # Run a script on a set of servers in the deployment in parallel
    # * friendly_name<~String> = the hash key name of the desired script to run
    # * set can be any way of denoting a set of servers to run on:
    # *** <~Array> will attempt to run the script on each server in set
    # *** <~String> will first attempt to find a function in the runner with that String to get
    # ***           an Array/ServerInterface to run on (e.g. app_servers, s_one). If that fails, then it
    # ***           will use the String as a regex to select a subset of servers.
    # *** <~Symbol> will attempt to run a function in the runner to get an Array/ServerInterface to run
    # ***           on (e.g. app_servers, s_one)
    # *** <~ServerInterface> will run the script only on that one server
    # * wait<~Boolean> will wait for the script to complete on all servers (true) or return
    #                  audits for each
    # * options<~Hash> will pass specific inputs to the script to run with
    def run_script_on_set(friendly_name, set = @servers, wait = true, options = nil)
      audits = Array.new() 
      set = select_set(set)
      set.each do |s|
        audits << launch_script(friendly_name, s, options)
      end
      if wait
        audits.each { |a| obj_behavior(a, :wait_for_completed) }
      elsif audits.size == 1
        return audits.first
      else
        return audits
      end
    end

    # Run a script on server in the deployment synchronously
    def run_script(friendly_name, server, options = nil)
      run_script_on_set(friendly_name, server, true, options)
    end

    # Run a script on server in the deployment asynchronously
    def launch_script(friendly_name, server, options = nil)
      raise "No script registered with friendly_name #{friendly_name} for server #{server.inspect}" unless script_to_run?(friendly_name, server)
      obj_behavior(server, :run_executable, @scripts_to_run[resource_id(server.server_template_href)][friendly_name], options)
    end

    # Call run_script_on_set with out-of-order params passed in as a hash
    def run_script!(friendly_name, hash = {})
      hash['servers'] = @servers unless hash['servers']
      hash['wait'] = true unless hash['wait']
      run_script_on_set(friendly_name, hash['servers'], hash['wait'], hash['options'])
    end

    # Returns false or true if a script with friendly_name has been registered for all or just one server
    def script_to_run?(friendly_name, server = nil)
      if server.nil? #check for all
        ret = true
        @server_templates.each { |st|
          if @scripts_to_run[resource_id(st)]
            ret &&= @scripts_to_run[resource_id(st)][friendly_name]
          else
            ret = false
          end
        }
      else
        if @scripts_to_run[resource_id(server.server_template_href)]
          ret = true if @scripts_to_run[resource_id(server.server_template_href)][friendly_name]
        else
          ret = false
        end
      end
      ret
    end

    
    # Detect operating system on each server and stuff the corresponding values for platform into the servers params (for temp storage only)
    def detect_os
      @server_os = Array.new
      @servers.each do |server|
#        if obj_behavior(server, :spot_check_command?, "lsb_release -is | grep Ubuntu")
        if probe(server, "lsb_release -is | grep Ubuntu")
          puts "setting server to ubuntu"
          server.os = "ubuntu"
          server.apache_str = "apache2"
          server.apache_check = "apache2ctl status"
          server.haproxy_check = "service haproxy status"
        else
          puts "setting server to centos"
          server.os = "centos"
          server.apache_str = "httpd"
          server.apache_check = "service httpd status"
          server.haproxy_check = "service haproxy check"
        end
      end
    end
    
    # Assumes the host machine is EC2, uses the meta-data to grab the IP address of this
    # 'tester server' eg. used for the input variation MASTER_DB_DNSNAME
    def get_tester_ip_addr
      if File.exists?("/var/spool/ec2/meta-data.rb")
        require "/var/spool/ec2/meta-data-cache" 
      else
        ENV['EC2_PUBLIC_HOSTNAME'] = "127.0.0.1"
      end
      my_ip_input = "text:" 
      my_ip_input += ENV['EC2_PUBLIC_HOSTNAME']
      my_ip_input
    end
    
    # Log rotation
    def force_log_rotation(server)
#      response = obj_behavior(server, :spot_check_command?, 'logrotate -f /etc/logrotate.conf')
      response = probe(server, 'logrotate -f /etc/logrotate.conf')
      raise "Logrotate restart failed" unless response
    end
    
    def log_check(server, logfile)
      response = nil
      count = 0
      until response || count > 3 do
#        response = obj_behavior(server, :spot_check_command?, "test -f #{logfile}")
        # test -f will only work if 1 file is returned.
        response = probe(server, "ls #{logfile}")
        break if response
        count += 1
        sleep 10
      end
      raise "Log file does not exist: #{logfile}" unless response
    end   

    # Checks that monitoring is enabled on all servers in the deployment.  Will raise an error if monitoring is not enabled.
    def check_monitoring
      @servers.each do |server|
        obj_behavior(server, :settings)
        response = nil
        count = 0
        until response || count > 20 do
          begin
            response = obj_behavior(server, :monitoring)
          rescue
            response = nil
            count += 1
            sleep 10
          end
        end
        raise "Fatal: Failed to verify that monitoring is operational" unless response
#TODO: pass in some list of plugin info to check multiple values.  For now just
# hardcoding the cpu check
        unless server.multicloud
          sleep 180 # This is to allow monitoring data to accumulate
          monitor = obj_behavior(server, :get_sketchy_data, {'start' => -60,
                                                                'end' => -20,
                                                                'plugin_name' => "cpu-0",
                                                                'plugin_type' => "cpu-idle"})
          idle_values = monitor['data']['value']
          raise "No cpu idle data" unless idle_values.length > 0
          raise "CPU idle time is < 0: #{idle_values}" unless idle_values[0] > 0
          puts "Monitoring is OK for #{server.nickname}"
        end
      end
    end



# TODO - we do not know what the RS_INSTANCE_ID available to the testing.
# For now we are checking at a high level that the services are working
# and then assume that the config file changes done during start are
# correct for the new instance data.
#
    def perform_start_stop_operations
      if deployment.nickname =~ /EBS/
        detect_os
        s = @servers.first
        # Save configuration files for comparison after starting
        save_configuration_files(s)
        # Stop the servers
        stop_ebs_all
        # Verify all stopped
        # Start the servers
        start_ebs_all(true)
#       Do this for all? Or just the one?
#       @servers.each { |server| server.wait_for_operational_with_dns }
        s = @servers.first
        obj_behavior(s, :wait_for_operational_with_dns)
        # Verify operational
        run_simple_check(s)
        check_monitoring
      end
    end

# TODO there will be other files that need compares et al.  Create a list
# of them and abstarct the tests
    # Copy configuration files into some location for usage after start
    def save_configuration_files(server)
      puts "Saving config files"
      probe(server, 'mkdir -p /root/start_stop_backup')
      probe(server, 'cp /etc/postfix/main.cf /root/start_stop_backup/.')
      probe(server, 'cp /etc/syslog-ng/syslog-ng.conf /root/start_stop_backup/.')
    end

    # Diff the new config file with the saved one and check that the only
    # line that is different is the one that has the mydestination change
    def test_mail_config(server)
      res = probe(server, 'diff /etc/postfix/main.cf /root/start_stop_backup/main.cf')
# This is lame - assuming if the file is modified then it's okay
        raise "ERROR: postfix main.cf configuration file did not change when restarted" unless res
    end
    
    def test_syslog_config(server)
      res = probe(server, 'diff /etc/syslog-ng/syslog-ng.conf /root/start_stop_backup/syslog-ng.conf')
# This is lame - assuming if the file is modified then it's okay
      raise "ERROR: syslog-ng configuration file did not change when restarted" unless res
    end
    
    def run_simple_checks
      @servers.each { |s| run_simple_check(s) }
    end
    
    # this is where ALL the generic application server checks live, this could get rather long but for now it's a single method with a sequence of checks
    def run_simple_check(server)
      test_mail_confi(server)
      test_syslog_config(server)
    end
  end
end
