set :runner, VirtualMonkey::Runner::SimpleWindowsNet

before do
  @runner.stop_all


  @runner.launch_all


  @runner.wait_for_all("operational")
end


test "default" do
#  @runner.check_monitoring
  @runner.run_script_on_all("backup")
  @runner.run_script_on_all("backup_database_check")
  @runner.run_script_on_all("restore")
  @runner.run_script_on_all("backup_to_s3")
  @runner.run_script_on_all("create_scheduled_task")
  @runner.run_script_on_all("delete_scheduled_task")
  @runner.run_script_on_all("register_with_elb")
  @runner.run_script_on_all("deregister_from_elb")
  @runner.run_script_on_all("update_code_svn")
end
