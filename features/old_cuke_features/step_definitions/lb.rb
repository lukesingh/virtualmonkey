require File.expand_path(File.join(File.dirname(__FILE__) , '..','..','spec','spec_helper'))

Given /^An Apache with HAproxy deployment/ do
  raise "FATAL:  Please set the environment variable $DEPLOYMENT" unless ENV['DEPLOYMENT']
  @runner = VirtualMonkey::FeAppRunner.new(ENV['DEPLOYMENT'])
end

Then /^I should run log rotation checks/ do
  @runner.log_rotation_checks
end

Then /^I should run frontend checks/ do
  @runner.frontend_checks
end

Then /^I should cross connect the frontends/ do
  @runner.cross_connect_frontends
end

Then /^I should set a variation LB_HOSTNAME/ do
  @runner.set_lb_hostname
end
