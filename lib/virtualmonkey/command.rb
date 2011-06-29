#!/usr/bin/env ruby
require 'rubygems'
require 'trollop'
require 'highline/import'
require 'uri'
require 'pp'

# Auto-require Section
some_not_included = true
files = Dir.glob(File.join(File.dirname(__FILE__), "command", "**"))
retry_loop = 0
while some_not_included and retry_loop < (files.size ** 2) do
  begin
    some_not_included = false
    for f in files do
      some_not_included ||= require f.chomp(".rb")
    end
  rescue SyntaxError => se
    raise se
  rescue Exception => e
    some_not_included = true
    files.push(files.shift)
  end
  retry_loop += 1
end

module VirtualMonkey
  module Command
    # Parses the initial command string, removing it from ARGV, then runs command.
    def self.go
      @@command = ARGV.shift
      @@global_state_dir = File.join(File.dirname(__FILE__), "..", "..", "test_states")
      @@features_dir = File.join(File.dirname(__FILE__), "..", "..", "features")
      @@cfg_dir = File.join(File.dirname(__FILE__), "..", "..", "config")
      @@runner_dir = File.join(File.dirname(__FILE__), "deployment_runners")
      @@mixin_dir = File.join(File.dirname(__FILE__), "runner_mixins")
      @@cv_dir = File.join(@@cfg_dir, "cloud_variables")
      @@ci_dir = File.join(@@cfg_dir, "common_inputs")
      @@troop_dir = File.join(@@cfg_dir, "troop")

      @@available_commands = {
        :api_check                  => "Verify API version connectivity",
        :audit_logs                 => "Execute Blacklist/Whitelist auditing of log files",
        :clone                      => "Clone a deployment n times and run though feature tests",
        :create                     => "Create MCI and Cloud permutation Deployments for a set of ServerTemplates",
        :destroy                    => "Destroy a set of Deployments",
        :destroy_ssh_keys           => "Destroy virtualmonkey-generated SSH Keys",
        :generate_ssh_keys          => "Generate SSH Key files per Cloud",
        :list                       => "List the full Deployment nicknames and Server statuses for a set of Deployments",
        :new_config                 => "Interactively create a new Troop Config JSON File",
        :new_runner                 => "Interactively create a new testing scenario and all necessary files",
        :populate_all_cloud_vars    => "Calls 'generate_ssh_keys', 'populate_datacenters', and 'populate_security_groups' for all Clouds",
        :populate_datacenters       => "Populates datacenters.json with API 1.5 hrefs per Cloud",
        :populate_security_groups   => "Populates security_groups.json with appropriate hrefs per Cloud",
        :run                        => "Execute a set of feature tests across a set of Deployments in parallel",
        :troop                      => "Calls 'create', 'run', and 'destroy' for a given troop config file",
        :update_inputs              => "Updates the inputs and editable server parameters for a set of Deployments",
        :help                       => "Displays usage information"
      }

      @@flags = {
        :terminate      => "opt :terminate, 'Terminate if tests successfully complete. (No destroy)',         :short => '-a', :type => :boolean",
        :common_inputs  => "opt :common_inputs, 'Input JSON files to be set at Deployment AND Server levels', :short => '-c', :type => :strings",
        :deployment     => "opt :deployment, 'regex string to use for matching deployment',                   :short => '-d', :type => :string",
        :config_file    => "opt :config_file, 'Troop Config JSON File',                                       :short => '-f', :type => :string",
        :clouds         => "opt :clouds, 'Space-separated list of cloud_ids to use',                          :short => '-i', :type => :integers",
        :keep           => "opt :keep, 'Do not delete servers or deployments after terminating',              :short => '-k', :type => :boolean",
        :list_trainer   => "opt :list_trainer, 'run through the interactive white- and black-list trainer.',  :short => '-l', :type => :boolean",
        :use_mci        => "opt :use_mci, 'List of MCI hrefs to substitute for the ST-attached MCIs',         :short => '-m', :type => :string, :multi => true",
        :n_copies       => "opt :n_copies, 'Number of clones to make',                                        :short => '-n', :type => :integer, :default => 1",
        :only           => "opt :only, 'Regex string to use for subselection matching on MCIs',               :short => '-o', :type => :string",
        :no_spot        => "opt :no_spot, 'do not use spot instances',                                        :short => '-p', :type => :boolean, :default => true",
        :qa             => "opt :qa, 'Special QA mode for exhaustively performing every possible test',       :short => '-q', :type => :boolean",
        :no_resume      => "opt :no_resume, 'Do not use trace info to resume a previous test',                :short => '-r', :type => :boolean",
        :tests          => "opt :tests, 'List of test names to run across Deployments (default is all)',      :short => '-t', :type => :strings",
        :verbose        => "opt :verbose, 'Print all output to STDOUT as well as the log files',              :short => '-v', :type => :boolean",
        :prefix         => "opt :prefix, 'Prefix of the Deployments',                                         :short => '-x', :type => :string",
        :yes            => "opt :yes, 'Turn off confirmation',                                                :short => '-y', :type => :boolean",
        :one_deploy     => "opt :one_deploy, 'Load all variations of a single ST into one Deployment',        :short => '-z', :type => :boolean"
      }

      max_width = @@available_commands.keys.map { |k| k.to_s.length }.max
      @@usage_msg = @@available_commands.to_a.sort { |a,b| a.first.to_s <=> b.first.to_s }.map { |k,v| "  %#{max_width}s:   #{v}" % k }.join("\n")

      @@usage_msg = "Valid commands for monkey:\n\n#{@@usage_msg}\n\n"
      @@usage_msg += "Help usage: 'monkey help <command>' OR 'monkey <command> --help'\n"
# TODO      @@usage_msg += "If this is your first time using Virtual Monkey, start with new_runner and new_config"

      if @@available_commands[@@command.to_sym]
        VirtualMonkey::Command.__send__(@@command)
      else
        STDERR.puts "Invalid command #{@@command}\n\n#{@@usage_msg}"
        exit(1)
      end
    end

    def self.use_options(*args)
      ret = []
      args.sort { |a,b| a.to_s <=> b.to_s }.each { |op|
        ret << @@flags[op]
      }
      return ret.join(";")
    end

    # Help command
    def self.help
      if subcommand = ARGV.shift
        ENV['REST_CONNECTION_LOG'] = "/dev/null"
        print `#{File.join(File.dirname(__FILE__), "..", "..", "bin", "monkey")} #{subcommand} --help`
      else
        puts @@usage_msg
      end
    end
  end
end
