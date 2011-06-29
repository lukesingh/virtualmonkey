module VirtualMonkey
  module Command
    # This command does all the steps create/run/conditionaly destroy
    def self.new_runner
      @@options = Trollop::options do
        text @@available_commands[:new_runner]
      end

      underscore_name = " "
      while underscore_name.gsub!(/ /,"")
        underscore_name = ask("What is the name for this runner? (Please use underscores instead of spaces), eg. 'mysql', 'php_chef', etc.)")
      end
      underscore_name.downcase!
      camel_case_name = underscore_name.camelcase
      common_inputs_file = File.join(@@ci_dir, "#{underscore_name}.json")
      feature_file = File.join(@@features_dir, "#{underscore_name}.rb")
      mixin_file = File.join(@@mixin_dir, "#{underscore_name}.rb")
      runner_file = File.join(@@runner_dir, "#{underscore_name}_runner.rb")
      troop_file = File.join(@@troop_dir, "#{underscore_name}.json")
      
      # Create inputs
      say("Creating example common inputs file...")
      File.open(common_inputs_file, "w") { |f| f.write("{'EXAMPLE_INPUT': 'text:value'}\n") }

      # Create feature
      say("Creating example feature file...")
      File.open(feature_file, "w") { |f| f.write(<<EOS
set :runner, VirtualMonkey::Runner::#{camel_case_name}

clean_start do
  @runner.stop_all
end

before "check_monitoring" do
  @runner.launch_all
  @runner.wait_for_all("operational")
end

test "Hello World" do
  puts "Hello World!"
end

test "check_monitoring" do
  @runner.check_monitoring
end

after do
  puts "Success!"
end
EOS
      )}

      # Create troop
      say("Creating troop config...")
      troop_config = {}
      troop_config[:prefix] = "#{underscore_name.upcase}_TROOP"
      correct = false
      until correct
        st_ary = []
        troop_config[:server_template_ids] = ask("What Server Template ids (or names) would you like to use to create the deployments (comma delimited)?").split(",")
        troop_config[:server_template_ids].each { |st|
          st.strip!
          st_ary << ServerTemplate.find(st.to_i)
        }
        puts st_ary.map { |st| st.nickname }.join("\n")
        correct = ask("Are these the ServerTemplates that you wish to use with this runner? (y/n)", lambda { |ans| true if (ans =~ /^[yY]{1}/) })
      end

      puts "Available Clouds:"
      VirtualMonkey::Toolbox::get_available_clouds().each { |cloud| puts "#{cloud['cloud_id']}: #{cloud['name']}" }
      list_of_clouds = ask("Enter a space-separated list of cloud_ids to use").split(" ")
      troop_config[:clouds] = list_of_clouds.map { |c| c.to_i }
      troop_config[:common_inputs] = File.basename(common_inputs_file)
      troop_config[:feature] = File.basename(feature_file)
      write_out = troop_config.to_json( :indent => "  ", 
                                        :object_nl => "\n",
                                        :array_nl => "\n" )
      File.open(troop_file, "w") { |f| f.write(write_out) }

      # Create mixin
      say("Creating mixin file...")
      mixin_tpl =<<EOS
module VirtualMonkey
  module Mixin
    module #{camel_case_name}
      def #{underscore_name}_lookup_scripts
EOS
      st_ary.uniq.each { |st|
        script_array = []
        op_execs = st.executables.select { |rs| rs.apply == "operational" }
        op_exec_names = op_execs.map { |rs| rs.recipe ? rs.recipe : rs.right_script["name"] }
        mixin_tpl += "        scripts = [\n"
        script_array = op_exec_names.map { |rs_name| "                   ['friendly_name', '#{rs_name}']" }
        mixin_tpl += "#{script_array.join(",\n")}\n"
        mixin_tpl += "                  ]\n"
        mixin_tpl += "        st = ServerTemplate.find(#{st.rs_id})\n"
        mixin_tpl += "        load_script_table(st,scripts)\n"
      }
      mixin_tpl += <<EOS
      end
    end
  end
end
EOS
      File.open(mixin_file, "w") { |f| f.write(mixin_tpl) }

      # Create runner
      say("Creating runner file...")
      runner_tpl =<<EOS
module VirtualMonkey
  module Runner
    class #{camel_case_name}
      include VirtualMonkey::Mixin::DeploymentBase
      include VirtualMonkey::Mixin::#{camel_case_name}

      # Override any functions from mixins here
    end
  end
end
EOS
      File.open(runner_file, "w") { |f| f.write(runner_tpl) }

      say("Created common_inputs file:  #{common_inputs_file}")
      say("Created feature file:        #{feature_file}")
      say("Created config file:         #{troop_file}")
      say("Created mixin file:          #{mixin_file}")
      say("Created runner file:         #{runner_file}")

      say("\nScenario created! DON'T FORGET TO CUSTOMIZE THESE FILES!");
    end
  end
end
