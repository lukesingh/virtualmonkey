set :runner, VirtualMonkey::Runner::ELB

before do
  @runner.create_elb
  @runner.stop_all
  @runner.set_master_db_dnsname
  @runner.set_elb_name
end

test "default"
  @runner.launch_set("App Server")
  @runner.wait_for_set("App Server", "booting")
  @runner.wait_for_set("App Server", "operational")
  @runner.run_elb_checks
  @runner.elb_registration_check(:all)
#  @runner.run_logger_audit
# should run log rotation checks
#  @runner.log_rotation_checks
#
# should check that monitoring is enabled
#  @runner.check_monitoring
#
# should reboot the servers
#  @runner.reboot_all
#
# should run EC2 Elastic Load Balancer unified_app checks
#  @runner.run_elb_checks
#
## Then all instances should be registered with ELB
#  @runner.elb_registration_check(:all)
#
# should run log rotation checks
#  @runner.log_rotation_checks
#
# should check that monitoring is enabled
#  @runner.check_monitoring
#

  @runner.stop_all

# Then no instances should be registered with ELB
  @runner.elb_registration_check(:none)

# When I delete EC2 Elastic Load Balancer
  @runner.destroy_elb

## When I launch the "App Server" servers
#  @runner.launch_set("App Server")
#
## When I should wait for the state of "App Server" servers to be "booting"
#  @runner.wait_for_set("App Server", "booting")
#
# should wait for the state of "App Server" servers to be "stranded"
#  @runner.wait_for_set("App Server", "stranded")
#
# should stop the servers
#  @runner.stop_all
end
