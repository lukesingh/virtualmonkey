set :runner, VirtualMonkey::Runner::Shutdown

before do
  @runner.stop_all
  @runner.launch_all
  @runner.wait_for_all("operational")
end

test "default" do
  @runner.run_script!("shutdown", {'wait' => false})
# Then the server should become terminated
  @runner.wait_for_all("stopped")
end
