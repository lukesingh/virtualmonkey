module VirtualMonkey
  module Command
  
# monkey destroy --tag unique_tag
    def self.destroy
      @@options = Trollop::options do
        text @@available_commands[:destroy]
        eval(VirtualMonkey::Command::use_options(:config_file, :only, :keep, :prefix, :yes))
      end

      raise "--config_file is required" unless @@options[:config_file]
      load_config_file
      @@dm = DeploymentMonk.new(@@options[:prefix])
      select_only_logic("Really destroy")
      destroy_all_logic
    end

  end
end
