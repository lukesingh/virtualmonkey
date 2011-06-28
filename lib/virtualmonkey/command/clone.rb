module VirtualMonkey
  module Command

# monkey clone --deployment name --feature testcase.rb --breakpoint 4 --copies 7
    def self.clone
      raise "Aborting" unless VirtualMonkey::Toolbox::api0_1?
      @@options = Trollop::options do
        opt :deployment, "regex string to use for matching deployment", :type => :string, :short => '-d', :required => true
        opt :feature, "path to feature(s) to run against the deployments", :type => :string
#        opt :breakpoint, "feature file line to stop at", :type => :integer, :short => '-b'
        opt :copies, "number of copies to make (default is 1)", :type => :integer, :short => '-c'
        opt :yes, "Turn off confirmation", :short => "-y"
        opt :verbose, "Print all output to STDOUT as well as the log files", :short => "-v"
        opt :list_trainer, "run through the interactive white- and black-list trainer after the tests complete"
        opt :qa, "Before destroying deployments, does a strict blacklist check (ignores whitelist)"
      end

      @@options[:copies] = 1 unless @@options[:copies] > 1
      @@options[:no_resume] = true
      @@options[:tag] = @@options[:deployment]
      @@dm = DeploymentMonk.new(@@options[:deployment])
      if @@dm.deployments.length > 1
        raise "FATAL: Ambiguous Regex; more than one deployment matched /#{@@options[:deployment]}/"
      elsif @@dm.deployments.length < 1
        raise "FATAL: Ambiguous Regex; no deployment matched /#{@@options[:deployment]}/"
      end
      origin = @@dm.deployments.first
      @@do_these ||= []
      # clone deployment
      for i in 1 .. @@options[:copies]
        new_deploy = origin.clone
        new_deploy.reload
        new_deploy.nickname = "#{origin.nickname}-clone-#{i}"
#        new_deploy.servers.each { |s|
#          s.save("nickname" => "#{s.nickname}-clone-#{i}")
#        }
        new_deploy.save
        @@do_these << new_deploy
      end

      # run to breakpoint
      run_logic if @@options[:feature]
    end
  end
end
