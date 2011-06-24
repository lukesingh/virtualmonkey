module VirtualMonkey
  class TestCase
    attr_accessor :options

    def initialize(file, options = {})
      @options = {}
      @before = {} 
      @test = {}
      @after = {}
      @options = options
      @tests_to_resume = nil
      ruby = IO.read(file)
      eval(ruby)
      self
    end

    def get_keys
      @test.keys
    end

    def check_for_resume
      # Should we resume?
      test_states = "test_states"
      state_dir = File.join(test_states, @options[:deployment])
      @options[:resume_file] = File.join(state_dir, File.basename(@options[:file]))
      if File.directory?(state_dir)
        if File.exists?(@options[:resume_file])
          unless @options[:no_resume]
            $stdout.syswrite "Resuming previous testcase...\n\n"
            # WARNING: There is an issue if you try to run a deployment through more than one feature at a time
            if File.mtime(@options[:resume_file]) < File.mtime(@options[:file])
              $stdout.syswrite "WARNING: testcase has been changed since state file.\n"
              $stdout.syswrite "Scrapping previous testcase; Starting over...\n\n"
              File.delete(@options[:resume_file])
            end
          else
            $stdout.syswrite "Scrapping previous testcase; Starting over...\n\n"
            File.delete(@options[:resume_file])
          end
        end
      else
        Dir.mkdir(test_states) unless File.directory?(test_states)
        Dir.mkdir(state_dir)
      end
      if File.exists?(@options[:resume_file])
        $stdout.syswrite "Confirmed resuming previous testcase, using paused tests...\n\n"
        @tests_to_resume = YAML::load(IO.read(@options[:resume_file])).first["tests"]
      end
    end

    def run(*tests_to_run)
      check_for_resume
      # Create Runner, initialize VirtualMonkey::log files
      @runner = @options[:runner].new(@options[:deployment], @options)
      # Set up tests_to_run
      tests_to_run = @tests_to_resume if @tests_to_resume
      tests_to_run = @test.keys if tests_to_run.empty?
      # Add the
      VirtualMonkey::trace_log.first["tests"] = tests_to_run
      # Before
      if @before[:all]
        @runner.write_readable_log("============== BEFORE ALL ==============")
        @before[:all].call
      end
      # Test
      tests_to_run.each { |key|
        if @before[key]
          @runner.write_readable_log("============== BEFORE #{key} ==============")
          @before[key].call
        end
        if @test[key]
          @runner.write_readable_log("============== #{key} ==============")
          @test[key].call
        end
        if @after[key]
          @runner.write_readable_log("============== AFTER #{key} ==============")
          @after[key].call
        end
      }
      # After
      if @after[:all]
        @runner.write_readable_log("============== AFTER ALL ==============")
        @after[:all].call
      end
      # Successful run, delete the resume file
      FileUtils.rm_rf @options[:resume_file]
      # For being friendly to tests (multiple TestCase instances in one test)
    ensure
      VirtualMonkey::trace_log = []
    end

    def set(var, arg)
      if arg.is_a?(Class) and var == :runner
        @options[:runner] = arg
      else
        raise "Need a VirtualMonkey::Runner Class!"
      end
    end

    def before(*args, &block)
      if args.empty?
        @before[:all] = block
      else
        args.each { |test_name| @before[test_name] = block }
      end
    end

    def test(*args, &block)
      args.each { |test_name| @test[test_name] = block }
    end

    def after(*args, &block)
      puts args.inspect
      if args.empty?
        @after[:all] = block
      else
        args.each { |test_name| @after[test_name] = block }
      end
    end
  end
end
