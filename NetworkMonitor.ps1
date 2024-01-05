# PowerShell script to monitor network connectivity and log average response times

# Define the IP addresses Google, Level3, Cloudflare
$ips = @("8.8.8.8", "4.2.2.2", "1.1.1.1")

# Define the maximum acceptable response time in milliseconds
$maxResponseTime = 200

# Initialize variables
$responseTimes = @{}
$ips | ForEach-Object { $responseTimes[$_] = @() }
$lastLogTime = Get-Date
$lastDownTime = Get-Date

# Initialize by assuming the connectivityDown is false (i.e. we have not previously lost connectivity)
$connectivityDown = $false
$bodyTemplate=@'
Network connectivity to the monitored IPs has been restored.
Outage start : {0}
Outage end   : {1}
'@

# Function to read configuration from JSON file
function Get-Config {
    param (
        [string]$ConfigPath
    )

    if (Test-Path $ConfigPath) {
        try {
			$configJson = Get-Content $ConfigPath | ConvertFrom-Json
		} catch {
			Write-Output "Failed to load ${ConfigPath}"
			exit 1
		}
		
        return $configJson
    }
    else {
        # Default configuration
        return @{
            emailEnable = $false
			smtpServer = "default-smtp.yourserver.com"
            smtpPort = 25
            smtpUser = "default-email@example.com"
            smtpPassword = "default-password"
            from = "default-email@example.com"
            to = "default-recipient-email@example.com"
            pingInterval = 10
            logInterval = 5
            logFilePath = "C:\NetworkMonitor.log"
        }
    }
}

# Function to write log
function Write-Log {
    param(
        [string]$Message
    )
	$timestampedMessage = "$((Get-Date).ToString()): $Message"
    Add-Content -Path $logFilePath -Value $timestampedMessage
	Write-Output $timestampedMessage
}

# Function to log average response times
function Log-AverageResponseTimes {
    $logMessage = "Average response times: "
    foreach ($ip in $ips) {
        $average = if ($responseTimes[$ip].Count -gt 0) { 
                      ($responseTimes[$ip] | Measure-Object -Average).Average 
                   } else { 
                      "N/A" 
                   }
				   
        # Check if $average is null and set it to a default value if it is
        if ($null -eq $average) {
            $average = 0
        }
		
        $averageString = [string]::Format("{0:N2}", $average)
        $logMessage += "${ip}: ${averageString} ms; "
    }
    Write-Log $logMessage
}

# Function to send email
function Send-Email {
    param(
        [string]$Body
    )

	if ($emailEnable) {
		$mailParams = @{
			SmtpServer = $smtpServer
			Port = $smtpPort
			From = $from
			To = $to
			Subject = "NetworkMonitor Status"
			Body = $Body
			UseSsl = $true
			Credential = New-Object System.Management.Automation.PSCredential -ArgumentList $smtpUser, (ConvertTo-SecureString $smtpPassword -AsPlainText -Force)
		}

		Send-MailMessage @mailParams
	}
}

# Path to the config file (same directory as the script)
$configPath = Join-Path -Path $PSScriptRoot -ChildPath "NetworkMonitor.json"
# Read configuration
$config = Get-Config -ConfigPath "NetworkMonitor.json"

# Email configuration
$emailEnable = $config.emailEnable
$smtpServer = $config.smtpServer
$smtpPort = $config.smtpPort
$smtpUser = $config.smtpUser
$smtpPassword = $config.smtpPassword
$from = $config.from
$to = $config.to
# Define the interval for pinging in seconds
$pingInterval = $config.pingInterval
# Define the interval for logging average response time in minutes
$logInterval = $config.logInterval
# Path to the log file
$logFilePath = $config.logFilePath

if ($emailEnable) {
	Write-Log "Startup with email enabled: ${smtpServer}:${smtpPort}"
} else {
	Write-Log "Startup with email disabled"
}
Write-Log "PingInterval = ${pingInterval} seconds"
Write-Log "LogInterval = ${logInterval} minutes"

while ($true) {
    # This is tracking if we have connectivity on this iteration. This flag is set to true once once of the pings succeeds
	$haveConnectivity = $false

    foreach ($ip in $ips) {
        $ping = Test-Connection -ComputerName $ip -Count 1 -Quiet

        if ($ping) {
            $pingInfo = Test-Connection -ComputerName $ip -Count 1
            $responseTime = 0
            # it appears there is a difference in output properties between Windows PowerShell and PowerShell Core
            if ($pingInfo.PSObject.Properties.Match('ResponseTime').Count -gt 0) {
                $responseTime = $pingInfo.ResponseTime
            } elseif ($pingInfo.PSObject.Properties.Match('Latency').Count -gt 0) {
                $responseTime = $pingInfo.Latency
            }

            $responseTimes[$ip] += $responseTime

            if ($responseTime -le $maxResponseTime) {
				
				# We will write in the log that connectivity is restored once ping succeeds and we had previously lost connectivity
                if ($connectivityDown) {
					$body = $bodyTemplate -f $lastDownTime, (Get-Date) 
					Write-Log $body
					Send-Email -Body $body
                    $connectivityDown = $false
                }
                $haveConnectivity = $true
                break
            }
        } else {
            $responseTimes[$ip] += 0
        }
    }

	# If we have lost connectivity on this iteration 
    if (-not $haveConnectivity) {
		# If we we had connectivity previously then write to log that we lost connectivity on this iteration
        if (-not $connectivityDown) {
            Write-Log "Network connectivity is down."
            $connectivityDown = $true
			$lastDownTime = Get-Date
        }
    }

    # Check if it's time to log the average response times
    if ((Get-Date) -ge $lastLogTime.AddMinutes($logInterval)) {
        Log-AverageResponseTimes
        $lastLogTime = Get-Date
        $ips | ForEach-Object { $responseTimes[$_] = @() }
    }

    Start-Sleep -Seconds $pingInterval
}
