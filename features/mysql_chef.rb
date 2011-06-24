set :runner, VirtualMonkey::Runner::MysqlChef

before do
  @runner.stop_all(true)
  @runner.set_variation_lineage
  @runner.set_variation_container
  @runner.set_variation_storage_type
#  @runner.setup_dns("virtualmonkey_shared_resources") # DNSMadeEasy
  @runner.launch_all
  @runner.wait_for_all("operational")
end

test "default" do
#  @runner.setup_block_device
#  @runner.do_backup
#  @runner.do_force_reset
#  @runner.do_restore
  @runner.test_multicloud
#  @runner.check_monitoring
#  @runner.check_mysql_monitoring
#  @runner.run_reboot_operations
#  @runner.check_monitoring
#  @runner.run_restore_with_timestamp_override
#  @runner.run_logger_audit
#  @runner.stop_all(true)
#  @runner.release_dns
end
