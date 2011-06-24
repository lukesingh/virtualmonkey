set :runner, VirtualMonkey::Runner::Lamp

before do
  @runner.stop_all


  @runner.launch_all


  @runner.wait_for_all("operational")
end

test "default" do

#  @runner.run_lamp_checks


#  @runner.run_checks

# Wordpress application checks
  @runner.test_http_response("html", "http://#{@runner.deployment.servers.first.dns_name}/wp-login.php", 80)


#  @runner.check_monitoring
#  @runner.run_logger_audit
end
