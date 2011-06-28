require 'eventmachine'
module VirtualMonkey
  module Command
  
# trollop supports Chronic for human readable dates. use with run command for delayed run?

# monkey run --feature --tag --only <regex to match on deploy nickname>
    def self.run
      raise "Aborting" unless VirtualMonkey::Toolbox::api0_1?
      @@options = Trollop::options do
        opt :feature, "path to feature(s) to run against the deployments", :type => :string, :required => true
#        opt :breakpoint, "feature file line to stop at", :type => :integer, :short => '-b'
        opt :tag, "Tag to match prefix of the deployments.", :type => :string, :required => true, :short => "-t"
        opt :only, "regex string to use for subselection matching on deployments.  Eg. --only x86_64", :type => :string
        opt :terminate, "Terminate if feature successfully completes. (No destroy)", :short => "-r"
        opt :no_resume, "Do not use current test-in-progress, start from scratch", :short => "-n"
        opt :yes, "Turn off confirmation", :short => "-y"
        opt :verbose, "Print all output to STDOUT as well as the log files", :short => "-v"
        opt :list_trainer, "run through the interactive white- and black-list trainer after the tests complete, before the deployments are destroyed"
        opt :qa, "Before destroying deployments, does a strict blacklist check (ignores whitelist)"
      end

      run_logic
    end
  end
end
