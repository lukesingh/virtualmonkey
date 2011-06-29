module VirtualMonkey
  module Command

# monkey update_inputs --common_inputs blah.json --tag unique_name --cloud_variables blah.json
    def self.update_inputs
      @@options = Trollop::options do
        text @@available_commands[:update_inputs]
        eval(VirtualMonkey::Command::use_options(:common_inputs, :prefix, :config_file, :clouds))
      end

      load_config_file if @@options[:config_file]
      @@dm = DeploymentMonk.new(@@options[:prefix])
      if @@options[:clouds]
        @@dm.load_clouds(@@options[:clouds])
#      elsif @@options[:cloud_variables]
#        @@options[:cloud_variables].each { |cvpath| @@dm.load_cloud_variables(cvpath) }
      end
      if @@options[:common_inputs]
        @@options[:common_inputs].each { |cipath| @@dm.load_common_inputs(cipath) }
      end
      @@dm.update_inputs
      @@dm.set_server_params
    end
  end
end
