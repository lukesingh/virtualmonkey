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
    @@trace_log ||= nil
  end

  module TestCaseInterface
    # Overrides backtick to provide stack tracing
    def `(cmd)
      @retry_loop << 0
      execution_stack_trace("system", [cmd])
      begin
        begin
          push_rerun_test
          #pre-command
          populate_settings if @deployment
          #command
          if @done_resuming
            result = super(cmd)
          else
            if VirtualMonkey::trace_log == YAML::load(IO.read(ENV['RESUME_FILE']))
              @done_resuming = true
            end
          end
          #post-command
          continue_test
        end while @rerun_last_command.pop
      ensure
        clean_stack_trace
        File.open(ENV["TRACE_FILE"], "w") { |f| f.write( VirtualMonkey::trace_log.to_yaml ) }
      end
      File.open(ENV["RESUME_FILE"], "w") { |f| f.write( VirtualMonkey::trace_log.to_yaml ) }
      @retry_loop.pop
      result
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
    def test_case_interface_init
      @log_checklists = {"whitelist" => [], "blacklist" => [], "needlist" => []}
      @rerun_last_command = []
      @stack_objects = []         # array holding the top most objects in the stack
      @iterating_stack = []       # stack that iterates
      @retry_loop = []
      @done_resuming = true
      if ENV['RESUME_FILE'] && File.exists?(ENV['RESUME_FILE'])
        @done_resuming = false     
      end
      # Do renaming stuff
      all_methods = self.methods + self.private_methods -
                    Object.new().methods - Object.new().private_methods -
                    VirtualMonkey::TestCaseInterface.instance_methods - VirtualMonkey::TestCaseInterface.private_instance_methods
      behavior_methods = all_methods.select { |m| m !~ /(^set)|(exception_handle)|(^__.*__$)/i }
      behavior_methods.each do |m|
        new_m = "behavior_#{m}"
#        klass = Kernel.const_get(self.class.to_s)
        self.class.class_eval("alias_method :#{new_m}, :#{m}; def #{m}(*args, &block); function_wrapper(:#{new_m}, *args, &block); end")
      end
    end
    
    def function_wrapper(sym, *args, &block)
      @retry_loop << 0
      execution_stack_trace(sym, args)
      begin
        begin
          push_rerun_test
          #pre-command
          populate_settings if @deployment
          #command
          result = __send__(sym, *args, &block)
          #post-command
          continue_test
        end while @rerun_last_command.pop
      ensure
#        clean_stack_trace
        File.open(ENV["TRACE_FILE"], "w") { |f| f.write( VirtualMonkey::trace_log.to_yaml ) }
      end
      File.open(ENV["RESUME_FILE"], "w") { |f| f.write( VirtualMonkey::trace_log.to_yaml ) }
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

    # probe executes a shell command over ssh to a set of servers is provides the following functionality:
    # * Execution Tracing
    # * Exception Handling
    # * Runner-Contextual Debugging
    # * Built-in retrying
    def probe(set, command, &block)
      # run command on set over ssh
      result_output = ""
      result_status = true
      @retry_loop << 0
      set_ary = select_set(set)
      execution_stack_trace("probe", [set_ary, command])

      set_ary.each { |s|
        begin
          push_rerun_test
          if @done_resuming
            result_temp = s.spot_check_command(command)
            if block
              if not yield(result_temp[:output],result_temp[:status])
                raise "FATAL: Server #{s.nickname} failed probe. Got #{result_temp[:output]}"
              end
            end
          else
            if VirtualMonkey::trace_log == YAML::load(IO.read(ENV['RESUME_FILE']))
              @done_resuming = true
            end
          end
          continue_test
        end while @rerun_last_command.pop
        result_output += result_temp[:output]
        result_status &&= (result_temp[:status] == 0)
      }
      clean_stack_trace
      @retry_loop.pop
      result_status
    end

    # Launches an irb debugging session if 
    def launch_irb_session(debug = false)
      IRB.start unless debug
      debugger if debug
    end

    private

    # Master exception_handle method. Calls all other exception handlers
    def __exception_handle__(e)
      all_methods = self.methods + self.private_methods
      exception_handle_methods = all_methods.select { |m| m =~ /exception_handle/ and m != "__exception_handle__" }
      
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
        list_methods = all_methods.select { |m| m =~ /#{list}/ }
        list_methods.each do |m|
          result = self.__send__(m)
          @log_checklists[list] += result if result.is_a?(Array)
        end
      end
    end

    # debugger irb help function
    def help
      puts "Here are some of the wrapper methods that may be of use to you in your debugging quest:\n"
      puts "behavior(sym, *args, &block): Pass the method name (as a symbol or string) and the optional arguments"
      puts "                              that you wish to pass to that method; behavior() will call that method"
      puts "                              with those arguments while handling nested exceptions, retries, and"
      puts "                              debugger calls. If a block is passed, it should take one argument, the"
      puts "                              return value of the function 'sym'. The block should always check"
      puts "                              if the return value is an Exception or not, and validate accordingly.\n"
      puts "                              Examples:"
      puts "                                behavior(:launch_all)"
      puts "                                behavior(:launch_set, 'Load Balancer')"
      puts "                                behavior(:run_script_on_all, 'fail') { |r| r.is_a?(Exception) }\n"
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
      unless @populated
        @populated = true
        @servers = @deployment.servers_no_reload
        @servers.reject! { |s|
          s.settings
          st = ServerTemplate.find(resource_id(s.server_template_href))
          ret = (st.nickname =~ /virtual *monkey/i)
          @server_templates << st unless ret
          ret
        }
        @server_templates.uniq!
        self.__send__(:__lookup_scripts__)
        self.__send__(:__list_loader__)
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

    # obj_behavior is meant to wrap every object member method call to provide the following functionality:
    # * Execution Tracing
    # * Exception Handling
    # * Runner-Contextual Debugging
    # * Built-in retrying
    def obj_behavior(obj, sym, *args, &block)
      execution_stack_trace(sym, args, obj)
      @retry_loop << 0
      begin
        push_rerun_test
        #pre-command
        populate_settings if @deployment
        #command
        puts @done_resuming
        if @done_resuming
          result = obj.__send__(sym, *args)
          if block
            raise "FATAL: Failed behavior verification. Result was:\n#{result.inspect}" if not yield(result)
          end
        else
          if VirtualMonkey::trace_log == YAML::load(IO.read(ENV['RESUME_FILE']))
            @done_resuming = true
          end
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
#      clean_stack_trace
      @retry_loop.pop
      result
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

    ##################################
    # Execution Stack Trace Routines #
    ##################################

    # Execution Stack Trace function
    def execution_stack_trace(sym, args, obj=nil)
      return nil unless VirtualMonkey::trace_log

      referenced_ary = []

      # Stringify Call
      arg_ary = args.map { |item| stringify_arg(item) }
      call = sym.to_s + "(#{arg_ary.join(", ")})"
      call = stringify_arg(obj) + "." + call if obj
      add_hash = { call => referenced_ary }

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

    # Cleanup stack trace output
    def clean_stack_trace
      # This is ugly code...I apologize, but it works
      return nil unless VirtualMonkey::trace_log
      ary = @stack_objects
      ary = VirtualMonkey::trace_log if ary.first.empty?
      ary.each { |temp|
        temp = VirtualMonkey::trace_log unless temp.is_a?(Array)
        temp.each_index { |i|
          if temp[i].is_a?(Hash)
            key = temp[i].keys.first
            if temp[i][key].is_a?(Array) and temp[i][key].empty?
              temp[i] = key
            end
          end
        }
      }
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
