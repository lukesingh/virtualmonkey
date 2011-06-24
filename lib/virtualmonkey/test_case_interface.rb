require 'irb'
if require 'ruby-debug'
  Debugger.start(:post_mortem => true) if ENV['MONKEY_NO_DEBUG'] != "true" and ENV['MONKEY_POST_MORTEM'] == "true"
end

module VirtualMonkey
  # Class Variables meant to be globally accessible, used for stack tracing
  def self.trace_log=(obj)
    @@trace_log = obj
  end

  def self.trace_log
    @@trace_log ||= []
  end

  module TestCaseInterface
    # Overrides puts to provide slightly better logging
    def puts(*args)
      write_readable_log("#{args}")
    end

    # Overrides raise to provide deep debugging abilities
    def raise(*args)
      begin
        super(*args)
      rescue Exception => e
        if not self.__send__(:__exception_handle__, e)
          if ENV['MONKEY_NO_DEBUG'] != "true" and ENV['MONKEY_POST_MORTEM'] != "true"
            puts "Got exception: #{e.message}" if e
            puts "Backtrace: #{e.backtrace.join("\n")}" if e
            puts "Pausing for inspection before continuing to raise Exception..."
#           if block
#              f, l = block.to_s.match(/@.*>/)[0].chop.reverse.chop.reverse.split(":")
#              puts "(Note: There is a block provided from \"#{f}\" at line #{l} that will attempt to handle the exception)"
#           end
            debugger
          end
          super(e)
        end
      end
    end

    # Gets called from runner_mixins/deployment_base.rb: initialize(...)
    def test_case_interface_init(options = {})
      @log_checklists = {"whitelist" => [], "blacklist" => [], "needlist" => []}
      @rerun_last_command = []
      # @stack_objects is an array of referenced arrays in the current call stack
      @stack_objects = []
      # @iterating_stack is the current scope of same-depth calls to which strings are appended
      @iterating_stack = []
      @retry_loop = []
      @done_resuming = true
      @in_transaction = false
      @already_in_transaction = false
      @options = options
      @deprecation_error = `curl -s "www.kdegraaf.net/cgi-bin/bofh" | grep -o "<b>.*</b>"`
      @deprecation_error.gsub!(/<\/*b>/,"")
      @deprecation_error.chomp!
      if @options[:resume_file] && File.exists?(@options[:resume_file])
        @done_resuming = false     
      end
      VirtualMonkey::trace_log << { "feature_file" => @options[:file] }
      write_readable_log("feature_file: #{@options[:file]}")
      # Do renaming stuff
      all_methods = self.methods + self.private_methods -
                    Object.new().methods - Object.new().private_methods -
                    VirtualMonkey::TestCaseInterface.instance_methods -
                    VirtualMonkey::TestCaseInterface.private_instance_methods
      behavior_methods = all_methods.select { |m| m !~ /(^set)|(exception_handle)|(^__.*__$)|(resource_id)|(^__behavior)/i }
      # SKIP this if we've already done the alias_method dance
      return if self.respond_to?("__behavior_#{behavior_methods.first}".to_sym)

      behavior_methods.each do |m|
        new_m = "__behavior_#{m}"
        self.class.class_eval("alias_method :#{new_m}, :#{m}; def #{m}(*args, &block); function_wrapper(:#{m}, *args, &block); end")
      end
    end
    
    def function_wrapper(sym, *args, &block)
      @retry_loop << 0
      execution_stack_trace(sym, args) unless block
      execution_stack_trace(sym, args, nil, block.to_ruby) if block
      begin
        push_rerun_test
        #pre-command
        populate_settings if @deployment
        #command
        result = __send__("__behavior_#{sym}".to_sym, *args, &block)
        #post-command
        continue_test
      end while @rerun_last_command.pop
      write_trace_log
      @retry_loop.pop
      result
    end

    # verify is meant to wrap every function call to provide the following functionality:
    # * Execution Tracing
    # * Exception Handling
    # * Runner-Contextual Debugging
    # * Built-in retrying
    def verify(sym, *args, &block)
      @retry_loop << 0
      execution_stack_trace(sym, args)
      begin
        push_rerun_test
        #pre-command
        populate_settings if @deployment
        #command
        result = __send__(sym, *args)
        if block
          raise "FATAL: Failed behavior verification. Result was:\n#{result.inspect}" if not yield(result)
        end
        #post-command
        continue_test
      rescue Exception => e
        if block and e.message !~ /^FATAL: Failed behavior verification/
          raise e if not yield(e)
        else
          raise e
        end
      end while @rerun_last_command.pop
      clean_stack_trace
      @retry_loop.pop
      result
    end

    # Launches an irb debugging session if 
    def launch_irb_session(debug = false)
      IRB.start unless debug
      debugger if debug
    end

    # transaction doesn't quite live up to its namesake. It only implies all-or-nothing resume capabilities,
    # rather than all-or-nothing execution.
    def transaction(ordered_ary = nil, &block)
      # TODO: Manage threaded execution across the elements of the ordered_ary. Remember to shift from a
      # duplicated ary rather than passing in args.
      #
      # threads = []
      # audits.each { |audit| threads << Thread.new(audit) { |a| a.wait_for_completed } }
      # threads.each { |t| t.join }
      #
      execution_stack_trace("transaction", [], nil, block.to_ruby)
      if @in_transaction
        @already_in_transaction = true
      else
        @in_transaction = true
        real_stack_objects = @stack_objects
        real_iterating_stack = @iterating_stack
        real_trace_log = VirtualMonkey::trace_log
        VirtualMonkey::trace_log = []
        @stack_objects = []
        @iterating_stack = []
      end

      result = nil
      begin
        #NOTE: Do not include retrying capabilities for transactions, it messes up trace_log
        populate_settings if @deployment
        if not @done_resuming
          if real_trace_log == YAML::load(IO.read(@options[:resume_file]))
            @done_resuming = true
          end
        end
        result = yield() if @done_resuming
      ensure
        if @already_in_transaction
          @already_in_transaction = false
        else
          # Merge transaction's trace 
          # NOTE: Needs to write out to readable log ONLY
          # Return class and instance variables to normal
          @iterating_stack = real_iterating_stack
          @stack_objects = real_stack_objects
          VirtualMonkey::trace_log = real_trace_log
        end
      end
      write_trace_log
      @in_transaction = false
      result
    end

    def write_readable_log(data)
      if @options[:log]
        data_ary = data.split("\n")
        data_ary.each_index do |i|
          data_ary[i] = timestamp + ("  " * @rerun_last_command.length) + data_ary[i]
        end
        File.open(@options[:log], "a") { |f| f.puts(data_ary.join("\n")) }
      end
    end

    private

    def obj_behavior(obj, sym, *args)
      puts "#{@deprecation_error.upcase} occured!  You are using a depricated method called 'obj_behavior'"
      transaction { obj.__send__(sym, *args) }
    end

    # Master exception_handle method. Calls all other exception handlers
    def __exception_handle__(e)
      all_methods = self.methods + self.private_methods
      exception_handle_methods = all_methods.select { |m| m =~ /exception_handle/ and m !~ /^__/ }
      
      exception_handle_methods.each { |m|
        if self.__send__(m,e)
          # If an exception_handle method doesn't return false, it handled correctly
          return true # Exception Handled
        end
      }
      # Exception wasn't handled
      return false
    end

    # Master list_loader method. Calls all other list load methods
    def __list_loader__
      all_methods = self.methods + self.private_methods
      MessageCheck::LISTS.each do |list|
        list_methods = all_methods.select { |m| m =~ /#{list}/ and m !~ /^__/ }
        list_methods.each do |m|
          result = self.__send__(m)
          @log_checklists[list] += result if result.is_a?(Array)
        end
      end
    end

    # debugger irb help function
    def help
      puts "Here are some of the wrapper methods that may be of use to you in your debugging quest:\n"
      puts "probe(server_set, shell_command, &block): Provides a one-line interface for running a command on"
      puts "                                          a set of servers and verifying their output. The block"
      puts "                                          should take one argument, the output string from one of"
      puts "                                          the servers, and return true or false based on however"
      puts "                                          the developer wants to verify correctness.\n"
      puts "                                          Examples:"
      puts "                                            probe('.*', 'ls') { |s| puts s }"
      puts "                                            probe(:fe_servers, 'ls') { |s| puts s }"
      puts "                                            probe('app_servers', 'ls') { |s| puts s }"
      puts "                                            probe('.*', 'uname -a') { |s| s =~ /x64/ }\n"
      puts "continue_test: Disables the retry loop that reruns the last command (the current command that you're"
      puts "               debugging.\n"
      puts "help: Prints this help message."
    end

    # Sets up most of the state for the runners
    def populate_settings
      @populated ||= false
      unless @populated
        @populated = true
        @servers = @deployment.servers_no_reload
        @servers.reject! { |s|
          s.settings
          st = ServerTemplate.find(resource_id(s.server_template_href))
          ret = (st.nickname =~ /virtual *monkey/i)
          @server_templates << st unless ret
          @st_table << [s, st] unless ret
          ret
        }
        @server_templates.uniq!
        self.__send__(:__lookup_scripts__)
        self.__send__(:__list_loader__)
      end
    end

    def match_servers_by_st(ref)
      @st_table.select { |s,st| st.href == ref.href }.map { |s,st| s }
    end

    def match_st_by_server(ref)
      @st_table.select { |s,st| s.href == ref.href }.last.last
    end

    def write_trace_log
      if @done_resuming and @options[:resume_file]
        File.open(@options[:resume_file], "w") { |f| f.write( VirtualMonkey::trace_log.to_yaml ) }
      end
    end

    # select_set returns an Array of ServerInterfaces and accepts any of the following:
    # * <~Array> will return the Array
    # * <~String> will first attempt to find a function in the runner with that String to get
    # *           an Array/ServerInterface (e.g. app_servers, s_one). If that fails, then it
    # *           will use the String as a regex to select a subset of servers.
    # * <~Symbol> will attempt to run a function in the runner to get an Array/ServerInterface
    # *           (e.g. app_servers, s_one)
    # * <~ServerInterface> will return a one-element Array with the ServerInterface
    def select_set(set = @servers)
      if set.is_a?(String)
        if self.respond_to?(set.to_sym)
          set = set.to_sym
        else
          set = @servers.select { |s| s.nickname =~ /#{set}/ }
        end
      end
      set = __send__(set) if set.is_a?(Symbol)
      set = [ set ] unless set.is_a?(Array)
      return set
    end

    # Encapsulates the logic necessary for retrying a function
    def push_rerun_test
      @rerun_last_command.push(true)
    end

    # Encapsulates the logic necessary for continuing after function
    def continue_test
      @rerun_last_command.pop
      @rerun_last_command.push(false)
    end

    # allows exceptions to only handle a limited number of times per behavior
    def incr_retry_loop
      @retry_loop.push(@retry_loop.pop() + 1)
    end

    def timestamp
      t = Time.now
      "#{t.strftime("[%m/%d/%Y %H:%M:%S.")}%-6d] " % t.usec
    end

    ##################################
    # Execution Stack Trace Routines #
    ##################################

    # Execution Stack Trace function
    def execution_stack_trace(sym, args, obj=nil, block_text="")
      return nil unless VirtualMonkey::trace_log

      referenced_ary = []
      # Stringify Call
      arg_ary = args.map { |item| stringify_arg(item) }
      call = sym.to_s
      call += "(#{arg_ary.join(", ")})" unless args.empty?
      call = stringify_arg(obj) + "." + call if obj
      call += block_text.gsub(/proc /, " ") if block_text != ""
      add_hash = { call => referenced_ary }
      write_readable_log(call)

      # Add string to proper place
      if @rerun_last_command.length < @stack_objects.length # shallower or same level call
        @stack_objects.pop(Math.abs(@stack_objects.length - @rerun_last_command.length))
      end
      if @stack_objects.empty?
        VirtualMonkey::trace_log << add_hash
      else
        @iterating_stack = @stack_objects.last # get the last object from the object stack
        @iterating_stack << add_hash # here were are adding to iterating stack
      end
      @stack_objects << referenced_ary
    end

    # Stringify stack_trace args
    def stringify_arg(arg, will_be_inspected = false)
      return arg.class.to_s if arg.is_a?(AuditEntry)
      return arg.inspect if arg.is_a?(Class)

      if arg.is_a?(Array)
        new_ary = arg.map { |item| stringify_arg(item, true) }
        return (will_be_inspected ? new_ary : new_ary.trace_inspect)
      end

      if arg.is_a?(Hash)
        new_hsh = {}
        arg.each { |k,v| new_hsh[ stringify_arg(k, true) ] = stringify_arg(v, true) }
        return (will_be_inspected ? new_hsh : new_hsh.trace_inspect)
      end

      return (will_be_inspected ? arg : arg.trace_inspect) if arg.respond_to?(:trace_inspect)
      return arg.class.to_s
    end
  end
end
