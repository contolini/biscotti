require 'io/console'

class GetConfig < Vagrant.plugin(2, :command)
  def execute
    config_files = Dir.glob("#{ENV['HOME']}/Library/Application Support/Viscosity/OpenVPN/*/config.conf")
    config_files.each do |file|
      certificate_files = ['ca', 'cert', 'key', 'tls-auth']
      config_dir        = File.dirname(file)
      connection_name   = nil
      new_config        = []

      File.read(file).each_line do |line|
        line.strip!

        if line.start_with?('#viscosity name')
          connection_name = line.match(/^#viscosity name (.*)/)[1]
          next
        end

        next if line.start_with?('#')
        (key, value) = line.split(/\s+/, 2)

        if certificate_files.include?(key)
          # Special case for tls-auth which is "key direction"
          if key == 'tls-auth'
            # add direction to config
            (value, direction) = value.split(/\s+/)
            new_config << "key-direction #{direction}" unless direction.nil?
          end

          certificate = File.read("#{config_dir}/#{value}")
          new_config  << "<#{key}>"
          new_config  << certificate
          new_config  << "</#{key}>"
          next
        end
        new_config << line
      end
      raise "Unable to find connection name in #{file}. Aborting." if connection_name.nil?
      new_config.unshift("# OpenVPN Config for #{connection_name}")
      out_file = "config.ovpn"
      File.open(out_file, 'w') { |f| f.write(new_config.join("\n") + "\n") }
      puts "Wrote #{out_file}"
    end
  end
end

class StartVpn < Vagrant.plugin(2, :command)
  def execute
    print "Username: "
    username = STDIN.gets.chomp
    print "Password: "
    password = STDIN.noecho(&:gets).chomp

    authfile = File.open('auth.txt', 'w')
    authfile.write username
    authfile.write "\n"
    authfile.write password
    authfile.close

    command = "sudo nohup openvpn --config /etc/openvpn/vpn.conf --script-security 2 --up /etc/openvpn/update-resolv-conf --auth-user-pass /tmp/auth.txt &"
    puts "\nRunning: #{command}"

    with_target_vms do |vm|
      ssh_opts = {extra_args: []}
      vm.action(:ssh_run, ssh_run_command: "mv /vagrant/auth.txt /tmp/auth.txt", ssh_opts: {extra_args: []})
      vm.action(:ssh_run, ssh_run_command: "sudo pkill openvpn", ssh_opts: {extra_args: []})
      env = vm.action(:ssh_run, ssh_run_command: command, ssh_opts: {extra_args: []})
      status = env[:ssh_run_exit_status] || 0
      return status
    end
  end
end

SSH_CONFIG = <<EOF
### BEGIN TUNNELBLINK CONFIG ###
Host tunnelblink
  HostName 127.0.0.1
  User vagrant
  Port 5122
  UserKnownHostsFile /dev/null
  StrictHostKeyChecking no
  PasswordAuthentication no
  IdentityFile /Users/#{ENV['USER']}/.vagrant.d/insecure_private_key
  IdentitiesOnly yes
  LogLevel FATAL

Host <host-behind-vpn>
  ProxyCommand ssh -A tunnelblink nc %h %p
### END TUNNELBLINK CONFIG ###

EOF

class SshConfig < Vagrant.plugin(2, :command)
  def execute
    puts "Add the following to your .ssh/config:\n\n"
    puts SSH_CONFIG
    puts "Replace <host-behind-vpn> with whatever host you want to add access to."
  end
end
