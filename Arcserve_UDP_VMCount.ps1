param(
    [string]$domain = [string]::Empty,
    [string]$user = $(throw "-user is required."),
    [string]$pass = $(Read-Host -asSecureString "Input password" ),
    [string]$historycountfrom,
    [string]$hostname = $env:computername
)

# IMPORTANT NOTE FOR THE SCRIPT IN DEBUG SO THE USERNAME/PASSWORD IS PRE-ENTERED
# IMPORTANT NOTE FOR THE SCRIPT IN DEBUG SO THE USERNAME/PASSWORD IS PRE-ENTERED
# IMPORTANT NOTE FOR THE SCRIPT IN DEBUG SO THE USERNAME/PASSWORD IS PRE-ENTERED
# IMPORTANT NOTE FOR THE SCRIPT IN DEBUG SO THE USERNAME/PASSWORD IS PRE-ENTERED
#$domain = ''
#$user = 'backup'
#$pass = ''
#$historycountfrom = 'JobSuccessCount'
#$hostname  = 'localhost' # host/ip-address

# You must try to set the right JobID for the VM job (try it first with 1): 
$RecentJobID = 1

if($hostname -eq "") { $hostname = $env:computername }

# hours back in history
$Hourstogoback=24

# parameters for WDSL call. Set the HTTPS/HTTPS protocol and the used port
$protocol = "https" # https or https
$port = 8015 #port nummer
$Debug=$False

Function NewJobHistoryObj($JobTypes, $JobStatuses)
{
    $jobHistoryCollection = @()

    $JobTypes | % {
        $jobHistoryData = New-Object PSObject
        Add-Member -InputObject $jobHistoryData -MemberType NoteProperty -Name JobType -Value $_
        Add-Member -InputObject $jobHistoryData -MemberType NoteProperty -Name JobStatuses -Value @{}
        $JobStatuses | % { $jobHistoryData.JobStatuses.Add($_, 0) }

        $jobHistoryCollection += $jobHistoryData
    }

    return $jobHistoryCollection
}

# This Don’t forget to change IP address/host name for domain variable above and in WSDL URI below 
$AllProtocols = [System.Net.SecurityProtocolType]'Tls11,Tls12'
[System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols

if($protocol -eq "https") {
	[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$True}
} else {
	[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$False}
}

$URI = $protocol+"://"+$hostname+":"+$port+"/services/UDPService?wsdl"
$agent = New-WebServiceProxy -Uri $URI -Namespace WebServiceProxy -Class UDPAgent
if($Debug) { "Agent: $agent" }

# We need cookie container to maintain session cookie 
$cookieContainer = New-Object system.Net.CookieContainer
$agent.CookieContainer = $cookieContainer

#lets authenticate against agent web service and print session ID 
if($Debug) { "agent.login($user,$pass,$domain)" }
$res = $agent.login($user,$pass,$domain)
if($Debug) { "Created new session $res" }

# Should consider using a DateTime CimType and migrating service into automation policy with a Powershell script instead of epoch
$timeNow = Get-Date
$earliest = $timeNow.AddHours(-$Hourstogoback)

$timenowUtc = $timeNow.ToUniversalTime()
$timestamp = (((((($timenowUtc.Year - 1970.0) * 31556926) + (($timenowUtc.Month - 1.0) * 2678400)) + (($timenowUtc.Day - 1.0) * 86400)) + ($timenowUtc.Hour * 3600)) + ($timenowUtc.Minute * 60)) + ($timenowUtc.Second)

# Read job history from Arcserve UDP
$jobHistory = $agent.getJobHistoryList($RecentJobID, $null, $null)

$jobHistoryData = $jobHistory.data |
					select  targetRPSId,
							jobUTCStartDate, 
							jobUTCEndDate,
							jobStatus,
							jobType,
							jobId,
							jobName,
							nodeName | ? { $_.jobUTCStartDate -ge $earliest }

#we can simply dump all log records to the console 
#Write-output "Retrieved $jobs.logs"
$JobInProgressCount=0
$JobSuccessCount=0
$JobFailedCount=0
$JobCancelledCount=0
$JobIdleCount=0
$JobWaitingCount=0
$JobIncompleteCount=0
$JobMissedCount=0
$JobOtherCount=0

#or we can have more elaborated logics
ForEach ($record in $jobHistoryData)
{
    #you may format and/or  feed data to external data cosumer or write into DB
	if($Debug) {
		Write-host "jobID: " $record.jobId " jobStatus: "  $record.jobStatus " nodeName: " $record.nodeName " jobType: " $record.jobType " jobTime: " $record.jobUTCStartDate " - " $record.jobUTCEndDate 
	}
	#Write-Host "$record.jobLocalEndTime"
 
	# JobTyp Values for all backup jobStatus
    #    BACKUP = 0,			# Client Backups
	#    VM_BACKUP = 3,			# VM Backups
    #    CATALOG_FS = 11,		# File System Catalog
	#    RPS_MERGE= 15			# Merge on RPS	
    #    RPS_REPLICATE = 22		# Replication Backups
	#    CATALOG_VM = 32		# File System Catalog VM
	
	# set the jopType for VM Backups
	if ($record.jobType -eq 3) {
	
        if ( $record.jobStatus -eq  "Active")
        {
            $JobInProgressCount+=1
        }
        elseif ( $record.jobStatus -eq  "Finished")
        {
            $JobSuccessCount+=1
        }
        elseif ( $record.jobStatus -eq  "Canceled")
        {
            $JobCancelledCount+=1
        }
        elseif ( $record.jobStatus -eq  "Failed")
        {
            $JobFailedCount+=1
        }
        elseif ( $record.jobStatus -eq  "Incomplete")
        {
            $JobIncompleteCount+=1
        }
        elseif ( $record.jobStatus -eq  "Idle")
        {
            $JobIdleCount+=1
        }
        elseif ( $record.jobStatus -eq  "Waiting")
        {
            $JobWaitingCount+=1
            
        }
        elseif ( $record.jobStatus -eq  "Crash")
        {
            $JobFailedCount+=1
            
        }
		elseif ( $record.jobStatus -eq  "LicenseFailed")
        {
            $JobFailedCount+=1
            
        }
        elseif ( $record.jobStatus -eq  "Missed")
        {
            $JobMissedCount+=1
            
        }
        else
        {
            $JobOtherCount+=1
        }
	}
}

$args = 
@{
JobInProgressCount = $JobInProgressCount;
JobSuccessCount = $JobSuccessCount;
JobFailedCount = $JobFailedCount;
JobCancelledCount = $JobCancelledCount;
JobIncompleteCount = $JobIncompleteCount;
JobIdleCount = $JobIdleCount;
JobWaitingCount = $JobWaitingCount;
JobMissedCount =  $JobMissedCount;
JobOtherCount = $JobOtherCount;
Timestamp = $timestamp
}

if($Debug) { Write-Host ($args | Format-Table | Out-String) }

[string]$args.$historycountfrom
