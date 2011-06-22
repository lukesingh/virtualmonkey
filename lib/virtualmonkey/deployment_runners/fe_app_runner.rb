module VirtualMonkey
  module Runner
    class FeApp
      include VirtualMonkey::Mixin::DeploymentBase
      include VirtualMonkey::Mixin::ApplicationFrontend
    end
  end
end
