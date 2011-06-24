  set :runner, VirtualMonkey::Runner::Simple
before do
  @runner.stop_all
  @runner.launch_all
end

test "default" do
  @runner.wait_for_all("operational")
  @runner.reboot_all
  @runner.wait_for_all("operational")
  @runner.reboot_all
  @runner.wait_for_all("operational")
  @runner.reboot_all
  @runner.wait_for_all("operational")
  @runner.reboot_all
  @runner.wait_for_all("operational")
  @runner.reboot_all
  @runner.wait_for_all("operational")
  @runner.reboot_all
  @runner.wait_for_all("operational")
end
