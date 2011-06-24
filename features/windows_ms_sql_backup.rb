set :runner, VirtualMonkey::Runner::SimpleWindowsSQL

before do
  @runner.stop_all


  @runner.launch_all


  @runner.wait_for_all("operational")
end

test "default" do

  @runner.check_monitoring



  @runner.run_script_on_all("EBS Create data and log volumes")
  @runner.run_script_on_all("sql_db_check")
  @runner.run_script_on_all("DB SQLS Configure tempdb")
  @runner.run_script_on_all("tempdb_check")
  @runner.run_script_on_all("DB SQLS create user")
  @runner.run_script_on_all("newuser_check")
  @runner.run_script_on_all("load_db")
  @runner.run_script_on_all("log_repair_before")
  @runner.run_script_on_all("DB SQLS Repair log files")
  @runner.run_script_on_all("log_repair_after")
  @runner.run_script_on_all("EBS Backup data and log volumes")
  @runner.run_script_on_all("DB SQLS DISABLE SERVER - snapshot, detach and delete volumes")

end
