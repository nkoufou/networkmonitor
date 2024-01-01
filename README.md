# NetworkMonitor
PowerShell script that is inspired by https://netuptimemonitor.com
The script will ping specified IP addresses at a regular interval and send an email when a response from all IPs was not received. I am using this to track the times when my ISP connection goes down.

**Configuration**

Configuration is controlled by NetworkMonitor.json. 
Other than SMTP configuration the ping frequency as well as response time log report frequency can be specified:

*"pingInterval"*: this should not be set to something no overly chatty, 10-20 seconds should be sufficient

*"logInterval"*: provides a average response time summary in console and in log file. Exmaple: Average response times: 8.8.8.8: 13.20 ms; 4.2.2.2: N/A ms; 1.1.1.1: N/A ms;

*"logFilePath"*: path to where to write out NetworkMonitor.log

**Email Configuration**

In the Google account under Security, the following had to be set: 2-step verification enabled and an app password had to be created that is then set as *"smtpPassword"*

**Output**

The script will write to console as well to the specified log file. A timestamp is included with each log line written. In addition when connectivity is restored it will attempt to email a report with outage start/end time.
