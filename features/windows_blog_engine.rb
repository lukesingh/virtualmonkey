set :runner, VirtualMonkey::Runner::SimpleWindowsBlog

before do
  @runner.stop_all
  @runner.launch_all
  @runner.wait_for_all("operational")
end

test "default" do
#  @runner.check_monitoring
  @runner.run_script_on_all("backup_database")
  @runner.run_script_on_all("backup_database_check")
  @runner.run_script_on_all("drop_database")
  @runner.run_script_on_all("restore_database")
end
