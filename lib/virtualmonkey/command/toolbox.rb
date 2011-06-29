module VirtualMonkey
  module Command
    def self.generate_ssh_keys
      @@options = Trollop::options do
        text @@available_commands[:generate_ssh_keys]
        opt :add_cloud, "Add a non-ec2 cloud to ssh_keys (takes the integer cloud id)", :type => :integer
        # TODO: Add ssh_key_id_ary...
      end

      VirtualMonkey::Toolbox::generate_ssh_keys(@@options[:add_cloud])
      puts "SSH Keyfiles generated."
    end

    def self.destroy_ssh_keys
      @@options = Trollop::options do
        text @@available_commands[:destroy_ssh_keys]
      end

      VirtualMonkey::Toolbox::destroy_ssh_keys()
      puts "SSH Keyfiles destroyed."
    end

    def self.populate_security_groups
      @@options = Trollop::options do
        text @@available_commands[:populate_security_groups]
        opt :add_cloud, "Add a non-ec2 cloud to security_groups (takes the integer cloud id)", :type => :integer
        opt :name, "Populate the file with this security group", :type => :string
      end

      VirtualMonkey::Toolbox::populate_security_groups(@@options[:add_cloud])
      puts "Security Group file populated."
    end

    def self.populate_datacenters
      @@options = Trollop::options do
        text @@available_commands[:populate_datacenters]
        opt :add_cloud, "Add a non-ec2 cloud to security_groups (takes the integer cloud id)", :type => :integer
      end

      VirtualMonkey::Toolbox::populate_datacenters(@@options[:add_cloud])
      puts "Datacenters file populated."
    end

    def self.populate_all_cloud_vars
      @@options = Trollop::options do
        text @@available_commands[:populate_all_cloud_vars]
        opt :force, "Forces command to continue if an exception is raised in a subcommand, populating as many files as possible."
      end

      VirtualMonkey::Toolbox::populate_all_cloud_vars(@@options[:force])
      puts "Cloud Variables folder populated."
    end

    def self.api_check
      @@options = Trollop::options do
        text @@available_commands[:api_check]
        opt :api_version, "Check to see if the monkey has RightScale API access for the given version (0.1, 1.0, or 1.5)", :type => :float, :required => true
      end

      if [0.1, 1.0, 1.5].include?(@@options[:api_version])
        ret = VirtualMonkey::Toolbox.__send__("api#{@@options[:api_version]}?".gsub(/\./,"_"))
        puts "#{ret}"
      else
        STDERR.puts "Invalid version number: #{@@options[:api_version]}"
      end
    end

    def self.audit_logs
      @@options = Trollop::options do
        text @@available_commands[:audit_logs]
        eval(VirtualMonkey::Command::use_options(:prefix, :only, :config_file, :qa, :list_trainer))
      end

      raise "--config_file is required" unless @@options[:config_file]
      load_config_file

      @@dm = DeploymentMonk.new(@@options[:prefix])
      select_only_logic("Train lists on")

      @@do_these.each { |d| audit_log_deployment_logic(d, @@options[:list_trainer]) }
    end
  end 
end
