module VirtualMonkey
  module Runner
    class ELB
      include VirtualMonkey::Mixin::DeploymentBase
      include VirtualMonkey::Mixin::ELB
    
      def initialize(*args)
        super(*args)
        raise "FATAL: ELBRunner must run on a single-cloud AWS deployment" unless @deployment.cloud_id
        endpoint_url = ELBS[@deployment.cloud_id][:endpoint]
        puts "USING EP: #{endpoint_url}"
        @elb = RightAws::ElbInterface.new(AWS_ID, AWS_KEY, { :endpoint_url => endpoint_url } )
        @elb_name = "#{ELB_PREFIX}-#{resource_id(@deployment)}"
      end
    end
  end
end
