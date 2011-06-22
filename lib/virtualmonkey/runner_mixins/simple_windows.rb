module VirtualMonkey
  module Mixin
    module SimpleWindows
      include VirtualMonkey::Mixin::DeploymentBase
      include VirtualMonkey::Mixin::Simple
  
      def simple_windows_exception_handle(e)
        puts "Got this \"#{e.message}\"."
        if e.message =~ /timed out waiting for the state to be operational/ and @retry_loop.last < 60
          puts "Got \"#{e.message}\". Retrying...."
          sleep 60
          incr_retry_loop
          return true # Exception Handled
        elsif e.message =~ /this server is stranded and needs to be operational/ and @retry_loop.last < 60
          puts "Got \"#{e.message}\". Retrying...."
          sleep 60
          incr_retry_loop
          return true # Exception Handled
        else
          return false
        end
      end
    end
  end
end
