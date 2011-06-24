set :runner, VirtualMonkey::Runner::Mysql

before do
  @runner.stop_all
  @runner.set_variation_lineage
  @runner.set_variation_stripe_count(1)
  @runner.setup_dns("virtualmonkey_awsdns") # AWSDNS
  @runner.launch_all
  @runner.wait_for_all("operational")
end

test "default" do
  @runner.run_promotion_operations
  @runner.run_checks
#  @runner.run_mysqlslap_check
#  @runner.ulimit_check
  @runner.probe(".*", "su - mysql -s /bin/bash -c \"ulimit -n\"") { |r,st| r.to_i > 1024 }
  @runner.check_monitoring
  @runner.check_mysql_monitoring

#
# PHASE 2) Reboot
#

  @runner.run_reboot_operations

#
# PHASE 3) Additional Tests
#

  @runner.run_restore_with_timestamp_override

#  @runner.run_logger_audit
# 
# PHASE 4) Terminate
#

  @runner.stop_all(true)
  @runner.release_dns
end
