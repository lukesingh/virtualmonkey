set :runner, VirtualMonkey::Runner::MonkeySelfTest

before do
  puts "ran before"
  @runner.launch_all
  @runner.wait_for_all("operational")
end

test "no-op" do
  puts "in no-op"
end

test "raise_exception" do
  @runner.transaction { puts "in test_exceptions" }
  @runner.transaction { @runner.raise_exception if rand(10) % 2 == 1 }
end

test "success_script" do
  puts 'im a great success'
end

#test "fail_script" do
#  @runner.verify(:run_script_on_all, "test", true, {"EXIT_VAL" => "text:1"}) { |res| res.is_a?(Exception) }
#end

after do
  puts "ran after"
end
