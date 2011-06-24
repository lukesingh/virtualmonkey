set :runner, VirtualMonkey::Runner::Simple
before do
# should stop the servers
# runner.behavior(:stop_all)

# should relaunch all servers
# runner.behavior(:relaunch_all)


  @runner.launch_all


  @runner.wait_for_all("operational")
end

test "default" do

  @runner.perform_start_stop_operations
#  @runner.run_logger_audit
end
