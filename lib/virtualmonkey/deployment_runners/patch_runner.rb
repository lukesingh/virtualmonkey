require "right_aws"
  
module VirtualMonkey
  module Runner
    class Patch
      include VirtualMonkey::Mixin::DeploymentBase
      
      # Grab the scripts we plan to exercise
      def patch_lookup_scripts
        scripts = [
                   [ 'test_patch', 'TEST' ]
                 ]
        st = ServerTemplate.find(resource_id(s_one.server_template_href))
        load_script_table(st,scripts)
      end 
  
      def set_user_data(value)
        @servers.each do |server|
          server.settings
          server.ec2_user_data = value
          server.save
        end
      end 
      
      # run the patch test script
      def run_patch_test
        run_script_on_all('test_patch')
      end
  
     end
  end
end
