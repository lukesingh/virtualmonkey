set :runner, VirtualMonkey::Runner::Dotnet

before do
  @runner.stop_all
  @runner.launch_all
  @runner.wait_for_all("operational")
end
test "default" do
  @runner.check_monitoring
  @runner.run_script_on_all('DB SQLS Download and attach DB')
  @runner.run_script_on_all('DB SQLS Create login')
  @runner.run_unified_application_checks(:s_one, 80)
  #@runner.run_script_on_all('IIS Download application code')
  #@runner.run_script_on_all('IIS Add connection string')
  #@runner.run_script_on_all('IIS Switch default website')
  
  #@runner.run_script_on_all('AWS Register with ELB')
  #@runner.run_script_on_all('AWS Deregister from ELB')

end
