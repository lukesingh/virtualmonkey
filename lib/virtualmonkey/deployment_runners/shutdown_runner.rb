module VirtualMonkey
  module Runner
    class Shutdown
      include VirtualMonkey::Mixin::DeploymentBase
      
      def shutdown_lookup_scripts
        scripts = [
                   [ 'shutdown', 'TEST shutdown' ]
                 ]
        st = ServerTemplate.find(resource_id(s_one.server_template_href))
        load_script_table(st,scripts)
      end
      
    end
  end
end
