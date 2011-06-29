module VirtualMonkey
  module Command
    # This command does all the steps create/run/conditionaly destroy
    def self.troop
      raise "Aborting" unless VirtualMonkey::Toolbox::api0_1?
      @@options = Trollop::options do
        text @@available_commands[:troop]
        eval(VirtualMonkey::Command::use_options( :config_file, :no_spot, :prefix, :use_mci, :qa, :verbose,
                                                  :one_deploy, :keep, :list_trainer, :clouds, :only))
      end
      #raise "You must select a single cloud id to create a singe deployment" if( @@options[:single_deployment] && (@@options[:cloud_override] == nil || @@options[:cloud_override].length != 1))  # you must select at most and at minimum 1 cloud to work on when the -z is selected
      # Execute Main
      load_config_file

      # CREATE PHASE
      @@dm = DeploymentMonk.new(@@options[:prefix],
                                @@options[:server_template_ids],
                                [], false, @@options[:single_deployment])
      unless @@dm.deployments.size > 0
        create_logic
      else
        puts "Existing deployments matching --prefix #{@@options[:prefix]} found. Skipping deployment creation."
      end
        
      run_logic
      puts "Troop done."
    end
  end
end
