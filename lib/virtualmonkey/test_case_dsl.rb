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
      @before[:all].call if @before[:all]
      # Test
      args = @test.keys if args.empty?
      args.each { |key|
        puts "RUNNING: #{key.inspect}"
        @before[key].call if @before[key]
        @test[key].call if @test[key]
        @after[key].call if @after[key]
      }
      # After
      @after[:all].call if @after[:all]
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

=begin

set :runner, VirtualMonkeyRunner.new

# Before ALL, for this file
before do
  @runner.set_variation_cpontainer(blah)
  @runner.setup_from_scratch
end

before "promote" do
  @runner.is_setup? # calls setup_from_scratch if not
end

test "restore" do

end

test "backup" do

end

test "promote" do

end

after "backup" do
  @runner.reset_to_pristine_from_backup
end

after do
  @runner.examine
  @runner.stop_all
end
=end  
