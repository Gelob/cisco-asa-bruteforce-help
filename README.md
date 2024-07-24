# cisco-asa-bruteforce-help
Scripts and configuration to help identify and block ASA bruteforce attempts

Cisco Talos Inteligence identified in April 2024 a [Large-scale brute-force activity targeting VPNs, SSH services with commonly used login credentials](https://blog.talosintelligence.com/large-scale-brute-force-activity-targeting-vpns-ssh-services-with-commonly-used-login-credentials/). While Cisco has published [hardening](https://www.cisco.com/c/en/us/support/docs/security/secure-client/221880-implement-hardening-measures-for-secure.html) and [best practices](https://www.cisco.com/c/en/us/support/docs/security/secure-firewall-threat-defense/221806-password-spray-attacks-impacting-custome.html) guides, they don't really help if you need to keep AAA authentication against the VPN.

That is why I've written a script to parse log files, and collect the IPs engaging in bruteforce to be used in a seperate firewall of your choice that is usually infront of the ASA. Think of this as fail2ban for your ASA, except we aren't blocking directly on the ASA and its no where near as fully featured as fail2ban.
## Prerequisites
- Cisco ASA setup to log to rsyslog or other equivalent logging system
- linux server to run the bash script where your logs are stored

## Helpful Notes
- ryslog template `$template RemoteHost,"/opt/syslog/%FROMHOST%/%$YEAR%/%$MONTH%/%$DAY%/syslog.txt"`
- Example ASA syslog message `Jul 23 20:30:27 myvpn.test.lab %ASA-6-113005: AAA user authentication Rejected : reason = AAA failure : server = 192.168.5.5 : user = ***** : user IP = 154.202.116.125`

## Usage
### badips.sh
You'll need to edit this script to fill in some directory paths
1. DIR_PATH: This is the path to your VPN logs. If you don't use the same syslog directory format you will need to adjust the script.
2. DIRECTORY: This is where you should put badips.sh, this is also where the script will store copies of all the bad IPs and their total amount of bruteforce attempts for later review if needed
3. WEB_DIR: The web directory where badips.txt will be copied to for download by your firewall
4. FILENAME (OPTIONAL): Edit this if you want to change the name of the bad ip files for later review

Test it out, run `chmod +x badips.sh` then `./badips.sh`. You should see output like this:
```
2024-07-23 20:46:16 - INFO: Current directory: /opt/syslog/myvpn.test.lab/2024/07/23
2024-07-23 20:46:16 - INFO: Wrote 2024-07-23_20-46-16_badips.txt with 146 bad IPs
2024-07-23 20:46:16 - INFO: INFO: Found no files to delete over 30 days
2024-07-23 20:46:16 - INFO: Wrote new badips.txt with total lines of 146
```

### Juniper SRX Configuration
In my network there is a Juniper SRX firewallq in front of the Cisco ASA. It has the ability to load dynamic IP lists from a URL. Its configured like this:
```
set security dynamic-address feed-server syslog01 hostname syslog01.test.lab
set security dynamic-address feed-server syslog01 update-interval 3600
set security dynamic-address feed-server syslog01 hold-interval 259200
set security dynamic-address feed-server syslog01 feed-name asablock path /badips/badips.txt
set security dynamic-address address-name address-blacklist profile feed-name asablock
```
You can verify that it is working by running `show security dynamic-address summary` and make sure `Total IPv4 entries` is not 0.

Then I create a security policy to match and drop traffic. Your zone names may be different than mine, and you need to make sure the deny is inserted before any permits you may have.
```
set security policies from-zone external to-zone dmz policy deny-badips match source-address address-blacklist
set security policies from-zone external to-zone dmz policy deny-badips match destination-address any
set security policies from-zone external to-zone dmz policy deny-badips match application any
set security policies from-zone external to-zone dmz policy deny-badips then deny
```
