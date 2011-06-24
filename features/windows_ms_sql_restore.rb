set :runner, VirtualMonkey::Runner::SimpleWindowsSQL

before do
  @runner.stop_all


  @runner.launch_all


  @runner.wait_for_all("operational")

end

test "default" do

  @runner.check_monitoring



  @runner.run_script_on_all("EBS Restore data and log volumes")
  @runner.run_script_on_all("sql_db_check")
  @runner.run_script_on_all("DB SQLS Rename instance")
  @runner.run_script_on_all("new_name_check")
end
