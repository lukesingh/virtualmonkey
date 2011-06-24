set :runner, VirtualMonkey::Runner::Simple

before do
  @runner.run_script_on_all("test", true, {"EXIT_VAL" => "text:1"}) { |res| res.is_a?(Exception) }
end
