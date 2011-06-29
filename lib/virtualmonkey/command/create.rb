module VirtualMonkey
  module Command

# monkey create --server_template_ids 123,123 --common_inputs blah.json --feature simple.feature --tag unique_name --TBD:filter?
    def self.create
      raise "Aborting" unless VirtualMonkey::Toolbox::api0_1?
      @@options = Trollop::options do
        text @@available_commands[:create]
        eval(VirtualMonkey::Command::use_options(:config_file, :clouds, :only, :no_spot, :one_deploy, :prefix))
      end

      raise "--config_file is required" unless @@options[:config_file]
      #raise "You must select a single cloud id to create a singe deployment" if( @@options[:single_deployment] && (@@options[:cloud_override] == nil || @@options[:cloud_override].length != 1))  # you must select at most and at minimum 1 cloud to work on when the -z is selected
      load_config_file
      @@dm = DeploymentMonk.new(@@options[:prefix], @@options[:server_template_ids],[],false, @@options[:one_deploy])
      create_logic
    end
  end
end
