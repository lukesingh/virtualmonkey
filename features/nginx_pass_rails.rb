set :runner, VirtualMonkey::Runner::NginxFeApp

before do
  @runner.stop_all
  @runner.set_master_db_dnsname
end

test "default" do
  @runner.launch_set("Front End")
  @runner.wait_for_set("Front End", "operational")
  @runner.set_lb_hostname
  @runner.launch_set("App Server")
  @runner.wait_for_set("App Server", "operational")
  @runner.cross_connect_frontends
  @runner.run_unified_application_checks(@runner.send(:app_servers))
  @runner.frontend_checks
  @runner.log_rotation_checks
  @runner.run_reboot_operations
  @runner.check_monitoring
#  @runner.run_logger_audit
end
