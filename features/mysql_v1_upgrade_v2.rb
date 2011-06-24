set :runner, VirtualMonkey::Runner::Mysql
before do
  @runner.stop_all
  @runner.set_variation_lineage
  @runner.set_variation_stripe_count(3)

#
# PHASE 2) Launch a new v2 server and migrate from v1
#

  @runner.launch_all
  @runner.wait_for_all("operational")
end

test "default" do
  @runner.create_migration_script
  @runner.migrate_slave

#
# PHASE 3) Initialize additional slave from v2 snapshots
#

  @runner.launch_v2_slave


  @runner.run_checks


  @runner.ulimit_check

#  @runner.run_logger_audit
end
