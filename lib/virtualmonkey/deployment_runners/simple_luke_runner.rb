module VirtualMonkey
  module Runner
    class SimpleLuke
      include VirtualMonkey::Mixin::DeploymentBase
      include VirtualMonkey::Mixin::Simple
    end
  end
end
