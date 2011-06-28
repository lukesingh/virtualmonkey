module VirtualMonkey
  module Command
    # Encapsulates the logic for selecting a subset of deployments
    def self.select_only_logic(message)
      @@do_these ||= @@dm.deployments
      if @@options[:only]
        @@do_these = @@do_these.select { |d| d.nickname =~ /#{@@options[:only]}/ }
      end   
      unless @@options[:no_resume] or @@command =~ /destroy|audit/
        temp = @@do_these.select do |d| 
          File.exist?(File.join(@@global_state_dir, d.nickname, File.basename(@@options[:feature])))
        end 
        @@do_these = temp if temp.length > 0 
      end 

      raise "No deployments matched!" unless @@do_these.length > 0 
      if @@options[:verbose]
        pp @@do_these.map { |d| { d.nickname => d.servers.map { |s| s.state } } }
      else
        pp @@do_these.map { |d| d.nickname }
      end
      unless @@options[:yes] or @@command == "troop"
        confirm = ask("#{message} these #{@@do_these.size} deployments (y/n)?", lambda { |ans| true if (ans =~ /^[y,Y]{1}/) }) 
        raise "Aborting." unless confirm
      end   
    end

    # Encapsulates the logic for loading the necessary variables to create a set of deployments
    def self.create_logic
      raise "Aborting" unless VirtualMonkey::Toolbox::api0_1?
      if @@options[:clouds]
        @@dm.load_clouds(@@options[:clouds])
      elsif @@options[:cloud_variables]
        @@options[:cloud_variables].each { |cvpath| @@dm.load_cloud_variables(cvpath) }
      else
        raise "Usage Error! Need either --clouds or --cloud_variables"
      end
      @@options[:common_inputs].each { |cipath| @@dm.load_common_inputs(cipath) }
      @@dm.generate_variations(@@options)
    end

    # Encapsulates the logic for launching and monitoring a set of asynchronous processes that run grinder
    # with a test case. Included is the logic for optionally destroying "successful" servers or
    # running "successful" servers through the log auditor/trainer.
    def self.run_logic
      raise "Aborting" unless VirtualMonkey::Toolbox::api0_1?
      @@options[:runner] = get_runner_class
      raise "FATAL: Could not determine runner class" unless @@options[:runner]

      EM.run {
        @@gm ||= GrinderMonk.new
        @@dm ||= DeploymentMonk.new(@@options[:tag])
        @@options[:runner] = get_runner_class
        select_only_logic("Run tests on")

        @@gm.options = @@options

        @@gm.run_tests(@@do_these, @@options[:feature])
#        @@do_these.each do |deploy|
#          @@gm.run_test(deploy, @@options[:feature])
#        end
        @@remaining_jobs = @@gm.jobs.dup

        watch = EM.add_periodic_timer(10) {
          @@gm.watch_and_report
          if @@gm.all_done?
            watch.cancel
          end
          
          if @@options[:terminate] and not (@@options[:list_trainer] or @@options[:qa])
            @@remaining_jobs.each do |job|
              if job.status == 0
                if @@command !~ /troop/ or @@options[:step] =~ /(all)|(destroy)/
                  destroy_job_logic(job)
                end
              end
            end
          end
        }
        if @@options[:list_trainer] or @@options[:qa]
          @@remaining_jobs.each do |job|
            if job.status == 0
              audit_log_deployment_logic(job.deployment, :interactive)
              if @@command !~ /troop/ or @@options[:step] =~ /(all)|(destroy)/
                destroy_job_logic(job) if @@options[:terminate]
              end
            end
          end
        end
      }
    end

    # Encapsulates the logic for running through the log auditor/trainer on a single deployment
    def self.audit_log_deployment_logic(deployment, interactive = false)
      @@options[:runner] = get_runner_class
      raise "FATAL: Could not determine runner class" unless @@options[:runner]
      runner = eval("VirtualMonkey::Runner::#{@@options[:runner]}.new(deployment.nickname)")
      puts runner.run_logger_audit(interactive, @@options[:qa])
    end

    # Encapsulates the logic for destroying the deployment from a single job
    def self.destroy_job_logic(job)
      @@options[:runner] = get_runner_class
      raise "FATAL: Could not determine runner class" unless @@options[:runner]
      runner = eval("VirtualMonkey::Runner::#{@@options[:runner]}.new(job.deployment.nickname)")
      puts "Destroying successful deployment: #{runner.deployment.nickname}"
      runner.stop_all(false)
      runner.deployment.destroy unless @@options[:no_delete] or @@command =~ /run|clone/
      @@remaining_jobs.delete(job)
      #Release DNS logic
      if runner.respond_to?(:release_dns) and not @@options[:no_delete]
        release_all_dns_domains(runner.deployment.href)
      end
      if runner.respond_to?(:release_container) and not @@options[:no_delete]
        runner.release_container
      end
    end

    # Encapsulates the logic for destroying all matched deployments
    def self.destroy_all_logic
      raise "Aborting" unless VirtualMonkey::Toolbox::api0_1?
      @@options[:runner] = get_runner_class
      raise "FATAL: Could not determine runner class" unless @@options[:runner]
      @@do_these ||= @@dm.deployments
      @@do_these.each do |deploy|
        runner = eval("VirtualMonkey::Runner::#{@@options[:runner]}.new(deploy.nickname)")
        runner.stop_all(false)
        state_dir = File.join(@@global_state_dir, deploy.nickname)
        if File.directory?(state_dir)
          puts "Deleting state files for #{deploy.nickname}..."
          Dir.new(state_dir).each do |state_file|
            if File.extname(state_file) =~ /((rb)|(feature))/
              File.delete(File.join(state_dir, state_file))
            end 
          end 
          Dir.rmdir(state_dir)
        end 
        #Release DNS logic
        if runner.respond_to?(:release_dns) and not @@options[:no_delete]
          release_all_dns_domains(deploy.href)
        end
        if runner.respond_to?(:release_container) and not @@options[:no_delete]
          runner.release_container
        end
      end 

      @@dm.destroy_all unless @@options[:no_delete]
    end

    # Encapsulates the logic for releasing the DNS entries for a single deployment, no matter what DNS it used
    def self.release_all_dns_domains(deploy_href)
      ["virtualmonkey_shared_resources", "virtualmonkey_awsdns", "virtualmonkey_dyndns"].each { |domain|
        begin
          dns = SharedDns.new(domain)
          raise "Unable to reserve DNS" unless dns.reserve_dns(deploy_href)
          dns.release_dns
        rescue Exception => e
          raise e unless e.message =~ /Unable to reserve DNS/
        end
      }
    end

    # Encapsulates the logic for detecting what runner is used in a test case file
    def self.get_runner_class #returns class string
      return @@options[:runner] if @@options[:runner]
      return @@options[:terminate] if @@options[:terminate].is_a?(String)
      return nil unless @@options[:feature]
=begin
      ret = nil 
      File.open(@@options[:feature], "r") { |f| 
        begin
          line = f.readline
          ret = $1 if line =~ /set.*VirtualMonkey::Runner::([^ ]*)/
        rescue EOFError => e
          ret = ""
        end while !ret
      }   
      return (ret == "" ? nil : ret)
=end
      return VirtualMonkey::TestCase.new(@@options[:feature]).options[:runner].to_s.split("::").last
    end
  end
end
