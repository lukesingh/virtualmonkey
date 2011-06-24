set :runner, VirtualMonkey::Runner::MysqlToolbox

before do
  @runner.setup_dns("virtualmonkey_shared_resources") # DNSMadeEasy
  @runner.set_variation_lineage
  @runner.set_variation_stripe_count(3)
  @runner.set_variation_volume_size(3)
  @runner.set_variation_mount_point("/mnt/mysql")
  @runner.stop_all
  @runner.launch_all
  @runner.wait_for_all("operational")
end

test "default" do
  @runner.create_master
  @runner.create_backup
  @runner.test_restore_grow
#  @runner.run_logger_audit
end
