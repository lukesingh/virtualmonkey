if require 'ruby-debug'
  Debugger.start(:post_mortem => true) if ENV['MONKEY_NO_DEBUG'] != "true" and ENV['MONKEY_POST_MORTEM'] == "true"
end

# Hash Patches

class Hash
  # Merges self with another second, recursively.
  #
  # This code was lovingly stolen from some random gem:
  # http://gemjack.com/gems/tartan-0.1.1/classes/Hash.html
  #
  # Thanks to whoever made it.
  #
  # Modified to provide same functionality with Arrays

  def deep_merge(second)
    target = dup
    return target unless second
    second.keys.each do |k|
      if second[k].is_a? Array and self[k].is_a? Array
        target[k] = target[k].deep_merge(second[k])
        next
      elsif second[k].is_a? Hash and self[k].is_a? Hash
        target[k] = target[k].deep_merge(second[k])
        next
      end
      target[k] = second[k]
    end
    target
  end
  
  # From: http://www.gemtacular.com/gemdocs/cerberus-0.2.2/doc/classes/Hash.html
  # File lib/cerberus/utils.rb, line 42
  # Modified to provide same functionality with Arrays

  def deep_merge!(second)
    return nil unless second
    second.each_pair do |k,v|
      if self[k].is_a?(Array) and second[k].is_a?(Array)
        self[k].deep_merge!(second[k])
      elsif self[k].is_a?(Hash) and second[k].is_a?(Hash)
        self[k].deep_merge!(second[k])
      else
        self[k] = second[k]
      end
    end
  end

  # test_case_interface hook for nice printing
  def trace_inspect
    inspect
  end
end

# Array Patches

class Array
  def deep_merge(second)
    target = dup
    return target unless second
    second.each_index do |k|
      if second[k].is_a? Array and self[k].is_a? Array
        target[k] = target[k].deep_merge(second[k])
        next
      elsif second[k].is_a? Hash and self[k].is_a? Hash
        target[k] = target[k].deep_merge(second[k])
        next
      end
      target[k] << second[k] unless target.include?(second[k])
    end
    target
  end

  def deep_merge!(second)
    return nil unless second
    second.each_index do |k|
      if self[k].is_a?(Array) and second[k].is_a?(Array)
        self[k].deep_merge!(second[k])
      elsif self[k].is_a?(Hash) and second[k].is_a?(Hash)
        self[k].deep_merge!(second[k])
      else
        self[k] << second[k] unless self.include?(second[k])
      end
    end
  end

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
