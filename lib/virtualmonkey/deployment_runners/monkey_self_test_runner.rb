module VirtualMonkey
  module Runner
    class MonkeySelfTest
      include VirtualMonkey::Mixin::DeploymentBase
      include VirtualMonkey::Mixin::Simple
  
      def raise_exception
        raise "FAIL"
      end
      #def monkey_self_test_lookup_scripts
      
  # scripts = [
   #                [ 'test', 'exit value' ]
    #             ]
    #    st = ServerTemplate.find(resource_id(s_one.server_template_href))
     #   load_script_table(st,scripts)
      #end
    end
  end
end
