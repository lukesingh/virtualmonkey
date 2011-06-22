module VirtualMonkey
  module Mixin
    module Chef
      def chef_download_once_lookup_scripts
        @servers.each { |s|
          Tag.set(s.href, ["rs_agent_dev:download_cookbooks_once=true"])
        }
      end
    end
  end
end
