require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'fileutils'

describe VirtualMonkey::TestCaseInterface do
  #it "does some metaprogrammy shit!" do
  #  r=VirtualMonkey::SimpleRunner.new("TIMR-MONKEY_SELF_TEST-cloud_1-745620-RightImage_CentOS_5.4_i386_v5.5")
  #   
  #end
  before(:each) do
 
    @options = {
      :deployment => "TIMR-MONKEY_SELF_TEST-cloud_1-745620-RightImage_CentOS_5.4_i386_v5.5", 
      :file => "/tmp/vmonk-testfile.rb",
      #:no_resume => true,
      :tests => "success_script" }

    feature_file_content =<<EOF
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

test "fail_script" do
  @runner.transaction {
    puts "before fail"
    raise "yep, gonna fail this time" if File.exists?("/tmp/testflag")
    puts "after fail"
    `touch /tmp/i_was_here_the_monkey`
  }
  @runner.transaction { puts "search_for_me" }
end

after do
  puts "ran after"
end
EOF
    File.open(@options[:file], "w") {|f| f.write(feature_file_content)} 
  end
=begin
  it "tests success" do
    @options[:tests] = "success_script" 
    test_case = VirtualMonkey::TestCase.new(@options[:file], @options)
    test_case.run(*@options[:tests])

    VirtualMonkey::readable_log.to_s.include?("success_script").should == true
  end
=end
  it "resumes" do
    # causes error if this file exists
    `touch /tmp/testflag`
    FileUtils.rm_rf "/tmp/i_was_here_the_monkey"
    @options[:tests] = "fail_script" 
    @options[:no_resume] = true
    test_case = VirtualMonkey::TestCase.new(@options[:file], @options)
    begin
      test_case.run(*@options[:tests])
    rescue
    end

    puts VirtualMonkey::trace_log
    VirtualMonkey::readable_log.to_s.include?("fail_script").should == true

    File.exists?('/tmp/i_was_here_the_monkey').should == false
    VirtualMonkey::readable_log.to_s.include?("search_for_me").should == false

    VirtualMonkey::trace_log = []
    VirtualMonkey::readable_log = []

    @options[:no_resume] = false
    FileUtils.rm_rf("/tmp/testflag")
    
    test_case = VirtualMonkey::TestCase.new(@options[:file], @options)
    test_case.run(*@options[:tests])

    puts VirtualMonkey::trace_log
    VirtualMonkey::readable_log.to_s.include?("fail_script").should == true
    VirtualMonkey::readable_log.to_s.include?("search_for_me").should == true
    File.exists?('/tmp/i_was_here_the_monkey').should == true
  end
end
