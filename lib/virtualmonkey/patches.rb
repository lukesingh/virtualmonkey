if require 'ruby-debug'
  Debugger.start(:post_mortem => true) if ENV['MONKEY_NO_DEBUG'] != "true" and ENV['MONKEY_POST_MORTEM'] == "true"
end

# Hash Patches

class Hash
  # test_case_interface hook for nice printing
  def trace_inspect
    inspect
  end
end

# Array Patches

class Array
  # test_case_interface hook for nice printing
  def trace_inspect
    inspect
  end

  # Experimental code for applying a method to each element in an Array
  def method_missing(method_name, *args, &block)
    if self.all? { |item| item.respond_to?(method_name) }
      return self.collect { |item| item.__send__(method_name, *args, &block) }
    else
      raise NoMethodError.new("undefined method '#{method_name}' for Array")
    end
  end
end

module Math
  # Added Absolute Value function
  def self.abs(n)
    (n > 0 ? n : 0 - n)
  end
end

module RightScale
  module Api
    module Base
#      include VirtualMonkey::TestCaseInterface
      # test_case_interface hook for nice printing
      def trace_inspect
        inspect
      end

      # test_case_interface hook for nice printing
      def inspect
        begin
          return "#{self.class.to_s}[#{self.nickname.inspect}]"
        rescue
          return "#{self.class.to_s}[#{self.rs_id}]"
        end
      end
    end
  end
end

class String
  # test_case_interface hook for nice printing
  def trace_inspect
    inspect
  end
end

class Symbol
  # test_case_interface hook for nice printing
  def trace_inspect
    inspect
  end
end

class Fixnum
  # test_case_interface hook for nice printing
  def trace_inspect
    inspect
  end
end

class NilClass
  # test_case_interface hook for nice printing
  def trace_inspect
    inspect
  end
end

class ServerInterface
  # test_case_interface hook for nice printing
  def trace_inspect
    @impl.trace_inspect
  end
end
