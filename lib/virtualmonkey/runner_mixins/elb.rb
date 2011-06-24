require "right_aws"
  
module VirtualMonkey
  module Mixin
    module ELB
      include VirtualMonkey::Mixin::DeploymentBase
      include VirtualMonkey::Mixin::Application
      include VirtualMonkey::Mixin::UnifiedApplication
      
      ELB_PORT = 80
      ELB_PORT_FORWARD = 8000
      ELB_PREFIX = "MONKEY-TEST-ELB"
      
      AWS_ID = ENV['AWS_ACCESS_KEY_ID']
      AWS_KEY = ENV['AWS_SECRET_ACCESS_KEY']
  
      ELBS = { 1 => { 
                  :endpoint => "https://elasticloadbalancing.us-east-1.amazonaws.com",
                  :azs => [ "us-east-1a", "us-east-1b", "us-east-1c", "us-east-1d" ]
                  },
               2 => {
                  :endpoint => "https://elasticloadbalancing.eu-west-1.amazonaws.com",
                  :azs => [ "eu-west-1a", "eu-west-1b" ] 
                  },
               3 => {
                  :endpoint => "https://elasticloadbalancing.us-west-1.amazonaws.com",
                  :azs => [ "us-west-1a", "us-west-1b" ] 
                  },
               4 => {
                  :endpoint => "https://elasticloadbalancing.ap-southeast-1.amazonaws.com",
                  :azs => [ "ap-southeast-1a", "ap-southeast-1a" ] 
                  },
               5 => {
                  :endpoint => "https://elasticloadbalancing.ap-northeast-1.amazonaws.com",
                  :azs => [ "ap-northeast-1a", "ap-northeast-1a" ]
                  }
            }
      
      # It's not that I'm a Java fundamentalist; I merely believe that mortals should
      # not be calling the following methods directly. Instead, they should use the
      # TestCaseInterface methods (behavior, verify, probe) to access these functions.
      # Trust me, I know what's good for you. -- Tim R.
      private
  
      def elb_exception_handle(e)
        if e.message =~ /throttling/i and @retry_loop.last < 10
          puts "Rescuing ELB error: #{e.message}"
          sleep (rand(60))
          incr_retry_loop
          return true # Exception Handled
        else
          return false
        end  
      end
  
      def set_elb_name
        obj_behavior(@deployment, :set_input, "ELB_NAME", "text:#{@elb_name}")
      end
      
      # The ELB should be serving up the unified app after boot
      def run_elb_checks
       run_unified_application_check(elb_href, ELB_PORT)
      end
      
      # Check if :all or :none of the app servers are registered
      def elb_registration_check(type)
        details = obj_behavior(@elb, :describe_load_balancers, @elb_name)
        instances = details.first[:instances]
        case type
        when :all
          @servers.each do |server|
            obj_behavior(server, :settings)
            aws_id = server["aws-id"]
            unless obj_behavior(instances, :include?, aws_id)
              raise "ERROR: Did not find aws id for #{aws_id}. ID list: #{instances.inspect}"
            end
          end
        when :none
          unless obj_behavior(instances, :empty?)
            raise "ERROR: found registered instances when there should be none. ID list: #{instances.inspect}"
          end
        else
          raise "ERROR: only check types of :none and :all are currently supported" 
        end
      end
      
      def elb_disconnect_all
        @servers.each do |server|
         disconnect_server(server)
        end
      end
      
      # Used to make sure everyone is disconnected
      def elb_response_code(elb_expected_code)
       test_http_response(elb_expected_code, elb_href, ELB_PORT)
      end
      
      # Grab the scripts we plan to excersize
      def elb_lookup_scripts
        scripts = [
                   [ 'connect', 'ELB connect' ],
                   [ 'disconnect', 'ELB disconnect' ]
                 ]
        st = ServerTemplate.find(resource_id(@servers.first.server_template_href))
        load_script_table(st,scripts)
      end 
      
      # This is really just a PHP server check. relocate?
      def log_rotation_checks
       detect_os
        
        # this works for php
        app_servers.each do |server|
         force_log_rotation(server)
         log_check(server, "/mnt/log/#{server.apache_str}/access.log.1")
        end
      end
      
      def create_elb
        # Check if elb exists
        ary = []
        obj_behavior(@elb, :describe_load_balancers, @elb_name) { |result|
          if result.is_a?(Exception)
            return result.message =~ /Cannot find Load Balancer|LoadBalancerNotFound/
          end
          ary = result
        }
        
        if ary.length == 1
          @elb_dns = ary.first[:dns_name]
        else
          raise "ERROR: More than one ELB with name \"#{@elb_name}\" found." if ary.length > 1
          az = ELBS[@deployment.cloud_id][:azs]
          puts "Using az: #{az}"
          @elb_dns = obj_behavior(@elb, :create_load_balancer, @elb_name, az, [{:protocol => :http,
                                                                                :load_balancer_port => ELB_PORT,
                                                                                :instance_port => ELB_PORT_FORWARD }])
        end
      end
      
      def destroy_elb
        success = obj_behavior(@elb, :delete_load_balancer, @elb_name)
        raise "ERROR: unable to delete ELB name=#{@elb_name}" unless success
      end
     
      def elb_href
        "http:\/\/#{@elb_dns}"
      end
      
      # run the ELB connect script
      def connect_server(server)
       run_script('connect', server)
      end
  
      # run the ELB disconnect script
      def disconnect_server(server)
       run_script('disconnect', server)
      end
      
     end
  end
end
