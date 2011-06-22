module VirtualMonkey
  class TestCase
    attr_accessor :options

    def initialize(file, options = {})
      @options = {}
      @before = {} 
      @test = {}
      @after = {}
      @options = options
      check_for_resume
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
      ENV['RESUME_FILE'] = File.join(state_dir, File.basename(@options[:file]))
      if File.directory?(state_dir)
        if File.exists?(ENV['RESUME_FILE'])
          unless @options[:no_resume]
            $stdout.syswrite "Resuming previous testcase...\n\n"
            # WARNING: There is an issue if you try to run a deployment through more than one feature at a time
            if File.mtime(ENV['RESUME_FILE']) < File.mtime(@options[:file])
              $stdout.syswrite "WARNING: testcase has been changed since state file.\n"
              $stdout.syswrite "Scrapping previous testcase; Starting over...\n\n"
              File.delete(ENV['RESUME_FILE'])
            end
          else
            $stdout.syswrite "Scrapping previous testcase; Starting over...\n\n"
            File.delete(ENV['RESUME_FILE'])
          end
        end
      else
        Dir.mkdir(test_states) unless File.directory?(test_states)
        Dir.mkdir(state_dir)
      end
    end

    def run(*args)
      # Before
      VirtualMonkey::readable_log << "\n============== BEFORE ALL ==============\n"
      @before[:all].call if @before[:all]
      # Test
      args = @test.keys if args.empty?
      args.each { |key|
        VirtualMonkey::readable_log << "\n============== #{key} ==============\n"
        @before[key].call if @before[key]
        @test[key].call if @test[key]
        @after[key].call if @after[key]
      }
      # After
      VirtualMonkey::readable_log << "\n============== AFTER ALL ==============\n"
      @after[:all].call if @after[:all]
      # Successful run, delete the resume file
      File.delete(ENV['RESUME_FILE'])
    end

    def set(var, arg)
      if arg.is_a?(Class) and var == :runner
        @runner = arg.new(@options[:deployment])
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
