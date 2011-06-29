module VirtualMonkey
  module Command

# monkey clone --deployment name --feature testcase.rb --breakpoint 4 --copies 7
    def self.clone
      raise "Aborting" unless VirtualMonkey::Toolbox::api0_1?
      @@options = Trollop::options do
        text @@available_commands[:clone]
        eval(VirtualMonkey::Command::use_options( :deployment, :config_file, :n_copies,
                                                  :yes, :verbose, :qa, :terminate))
      end

      @@options[:prefix] = @@options[:deployment]
      @@dm = DeploymentMonk.new(@@options[:deployment])
      if @@dm.deployments.length > 1
        raise "FATAL: Ambiguous Regex; more than one deployment matched /#{@@options[:deployment]}/"
      elsif @@dm.deployments.length < 1
        raise "FATAL: Ambiguous Regex; no deployment matched /#{@@options[:deployment]}/"
      end
      origin = @@dm.deployments.first
      @@do_these ||= []
      # clone deployment
      for i in 1 .. @@options[:n_copies]
        new_deploy = origin.clone
        new_deploy.reload
        new_deploy.nickname = "#{origin.nickname}-clone-#{i}"
        new_deploy.save
        @@do_these << new_deploy
      end

      # run to breakpoint
      run_logic if @@options[:config_file]
    end
  end
end
