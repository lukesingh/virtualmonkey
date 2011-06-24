set :runner, VirtualMonkey::Runner::Jenkins

before do
  @runner.set_variation_lineage
  @runner.set_variation_container
  @runner.set_variation_storage_type
  @runner.stop_all
  @runner.launch_all
  @runner.wait_for_all("operational")
end

test "default" do
  @runner.do_prep
  @runner.test_multicloud
  @runner.check_monitoring
  @runner.reboot_all
  @runner.wait_for_all("operational")
  @runner.check_monitoring
  @runner.check_app_monitoring
  @runner.test_http
  @runner.run_logger_audit
end
