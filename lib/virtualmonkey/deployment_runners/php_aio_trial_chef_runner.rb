module VirtualMonkey
  module Runner
    class PhpAioTrialChef
      include VirtualMonkey::Mixin::DeploymentBase
      include VirtualMonkey::Mixin::ApplicationFrontend
    end
  end
end
