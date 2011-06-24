set :runner, VirtualMonkey::Runner::Onboarding
before do
  @runner.stop_all
  @runner.launch_all
  @runner.wait_for_all("operational")
end

test "default" do
  @runner.run_onboarding_checks
  @runner.probe(".*", "su - mysql -s /bin/bash -c \"ulimit -n\"") { |r,st| r.to_i > 1024 }
  @runner.check_monitoring
  @runner.check_passenger_monitoring
#  @runner.run_logger_audit
end
