set :runner, VirtualMonkey::Runner::EBS

before do
  @runner.set_variation_lineage
  @runner.set_variation_stripe_count(3)
  @runner.set_variation_volume_size(3)
  @runner.set_variation_mount_point("/mnt/ebs")
  @runner.stop_all
  @runner.launch_all
  @runner.wait_for_all("operational")
end

test "default" do
  @runner.create_stripe

##
## PHASE 2) Run checks for the basic scripts
##

  @runner.test_backup_script_operations

##
## PHASE 3) restore the snapshot on another server
##

  @runner.create_backup


  @runner.test_restore

##
## PHASE 4) Do the grow EBS tests
##

  @runner.test_restore_grow


  @runner.run_reboot_operations

#  @runner.run_logger_audit

end
