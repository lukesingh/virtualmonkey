  set :runner, VirtualMonkey::Runner::Simple

before do
  @runner.stop_all
  @runner.launch_all
  @runner.wait_for_all("operational")
end

test "default" do
  @runner.check_monitoring
  @runner.reboot_all
  @runner.wait_for_all("operational")
  @runner.check_monitoring
#  @runner.run_logger_audit
end
