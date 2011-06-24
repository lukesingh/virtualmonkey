set :runner, VirtualMonkey::Runner::MysqlV2Migration
before do
  @runner.stop_all
  @runner.set_variation_lineage
  @runner.set_variation_stripe_count(3)
end
#
# PHASE 2) Launch a new v2
#
test "default" do
  @runner.launch_set(:s_one)
  @runner.wait_for_set(:s_one, "operational")
  @runner.run_promotion_operations

#
# PHASE 3) Initialize additional slave from db_manager snapshots
#

  @runner.launch_set(:s_two)


  @runner.wait_for_set(:s_two, "operational")


  @runner.launch_db_manager_slave


  @runner.run_checks

#  @runner.run_logger_audit
end
