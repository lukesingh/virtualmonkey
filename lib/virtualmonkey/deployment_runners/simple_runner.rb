module VirtualMonkey
  module Runner
    class Simple
      include VirtualMonkey::Mixin::DeploymentBase
      include VirtualMonkey::Mixin::Simple
    end
  end
end
