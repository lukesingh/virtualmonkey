set :runner, VirtualMonkey::Runner::DrToolbox
before do
  @runner.set_variation_lineage
  @runner.set_variation_container
  @runner.set_variation_storage_type("ros")
  @runner.stop_all
  @runner.launch_all
  @runner.wait_for_all("operational")
end

  #@runner.test_s3
  #@runner.test_ebs
  #@runner.test_cloud_files
