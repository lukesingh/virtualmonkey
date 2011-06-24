set :runner, VirtualMonkey::Runner::Postgres

before do
  @runner.stop_all
  @runner.set_variation_lineage
  @runner.set_variation_stripe_count(1)
  @runner.set_variation_volume_size(3)
  @runner.set_variation_mount_point("/mnt/pgsql")
  @runner.setup_dns("virtualmonkey_shared_resources") # DNSMadeEasy
  @runner.launch_all
  @runner.wait_for_all("operational")
end

test "default" do
  @runner.run_promotion_operations
  @runner.run_checks
  @runner.probe(".*", "su - postgres -s /bin/bash -c \"ulimit -n\"") { |r, st| r.to_i > 1024 }
  @runner.check_monitoring
  @runner.check_db_monitoring

#
# PHASE 2) Reboot
#

  @runner.run_reboot_operations

#
# PHASE 3) Additional Tests
#

  @runner.run_restore_with_timestamp_override
  @runner.run_dump_import
  @runner.dump_export

#  @runner.run_logger_audit

## PHASE 4) Do the grow EBS tests
##

  @runner.test_restore_grow

# 
# PHASE 5) Terminate
#


  @runner.stop_all(true)


  @runner.release_dns
end
