set :runner, VirtualMonkey::Runner::Mysql
before do
  @runner.stop_all
  @runner.set_variation_lineage
  @runner.set_variation_stripe_count(1)
  @runner.setup_dns("virtualmonkey_shared_resources") # DNSMadeEasy
  @runner.launch_all
  @runner.wait_for_all("operational")
end
test "default" do
  @runner.init_slave_from_slave_backup
  @runner.run_checks
  @runner.check_monitoring

  #@runner.run_logger_audit

  # 
  # PHASE 4) Terminate
  #

  @runner.stop_all(true)
  @runner.release_dns
end
