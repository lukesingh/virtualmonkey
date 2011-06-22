module VirtualMonkey
  module Runner
    class NginxFeApp
      include VirtualMonkey::Mixin::DeploymentBase
      include VirtualMonkey::Mixin::NginxApplicationFrontend
    end
   end
end
