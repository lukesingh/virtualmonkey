require 'eventmachine'
module VirtualMonkey
  module Command
  
# trollop supports Chronic for human readable dates. use with run command for delayed run?

# monkey run --feature --tag --only <regex to match on deploy nickname>
    def self.run
      raise "Aborting" unless VirtualMonkey::Toolbox::api0_1?
      @@options = Trollop::options do
        text @@available_commands[:run]
        eval(VirtualMonkey::Command::use_options( :config_file, :prefix, :only, :yes, :verbose, :qa,
                                                  :list_trainer, :keep, :terminate))
      end

      run_logic
    end
  end
end
