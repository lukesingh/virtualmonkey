module VirtualMonkey
  module Runner
    class SimpleBasicWindows
      include VirtualMonkey::Mixin::DeploymentBase
      include VirtualMonkey::Mixin::SimpleWindows
    end
  end
end
