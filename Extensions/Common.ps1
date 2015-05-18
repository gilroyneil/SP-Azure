#
# Copyright="© Microsoft Corporation. All rights reserved."
#

function Decrypt
{
    param
    (
        [Parameter(Mandatory)]
        [String]$Thumbprint,

        [Parameter(Mandatory)]
        [String]$Base64EncryptedValue
    )

    # Decode Base64 string
    $encryptedBytes = [System.Convert]::FromBase64String($Base64EncryptedValue)

    # Get certificate from store
    $store = new-object System.Security.Cryptography.X509Certificates.X509Store([System.Security.Cryptography.X509Certificates.StoreLocation]::LocalMachine)
    $store.open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)
    $certificate = $store.Certificates | %{if($_.thumbprint -eq $Thumbprint){$_}}

    # Decrypt
    $decryptedBytes = $certificate.PrivateKey.Decrypt($encryptedBytes, $false)
    $decryptedValue = [System.Text.Encoding]::UTF8.GetString($decryptedBytes)

    return $decryptedValue
}

function WaitForPendingMof
{
    # Check to see if there is a Pending.mof file to avoid a conflict with an
    # already in-progress SendConfigurationApply invocation.
    while ($true)
    {
        try
        {
            Get-Item -Path "$env:windir\System32\Configuration\Pending.mof" -ErrorAction Stop
            Start-Sleep -Seconds 5
        }
        catch
        {
            break
        }
    }
}

function CheckForPendingReboot
{
    param
    (
        [Parameter(Mandatory)]
        [Object[]]$Output
    )

    # The LCM doesn't notify us when there's a pending reboot, so we have to check
    # for it ourselves.
    if ($Output -match "A reboot is required to progress further. Please reboot the system.")
    {
        Start-Sleep -Seconds 5
        Restart-Computer -Force
    }
}

function WaitForSqlSetup
{
    # Wait for SQL Server Setup to finish before proceeding.
    while ($true)
    {
        try
        {
            Get-ScheduledTaskInfo "\ConfigureSqlImageTasks\RunConfigureImage" -ErrorAction Stop
            Start-Sleep -Seconds 5
        }
        catch
        {
            break
        }
    }
}

# This function implement backoff retry algorithm based
# on exponential backoff. The backoff value is truncated
# using the upper value after advancing it using the
# multiplier to govern the maximum backoff internal.
# The initial value is picked randomly between the minimum
# and upper limit with a bias towards the minimum.
function Get-TruncatedExponentialBackoffDelay([int]$PreviousBackoffDelay, [int]$LowerBackoffBoundSeconds, [int]$UpperBackoffBoundSeconds, [int]$BackoffMultiplier)
{
   [int]$delay = "0"

   if($PreviousBackoffDelay -eq 0)
   {
      $PreviousBackoffDelay = Get-Random -Minimum $LowerBackoffBoundSeconds -Maximum ($LowerBackoffBoundSeconds + ($UpperBackoffBoundSeconds / 2))
      $delay = $PreviousBackoffDelay
   }
   else
   {
       $delay = ($PreviousBackoffDelay * $BackoffMultiplier);

       if($delay -ge $UpperBackoffBoundSeconds)
       {
           $delay = $UpperBackoffBoundSeconds
       }
       elseif($delay -le $LowerBackoffBoundSeconds)
       {
           $delay = $LowerBackoffBoundSeconds
       }
   }

   return $Result = $delay
}

# This function starts script logging and saves it to a local file
# Logging is under the current SystemDrive under DeploymentLogs folder.
# If the folder does not exists, then it is created.
function Start-ScriptLog
{
    param
    (
        [String]$LogName
    )

    $logDirectory = $env:SystemDrive + "\DeploymentLogs"
    if (($LogName -ne $null) -or ($LogName -ne ""))
    {
        $logFilePath = $logDirectory + "\" + $LogName + ".txt"    
    }
    else
    {    
        $logFilePath = $logDirectory + "\log.txt"
    }

    if(!(Test-Path -Path $logDirectory ))
    {
        New-Item -ItemType Directory -Path $logDirectory
    }

    try
    {
       Start-Transcript -Path $logFilePath -Append -Force
    }
    catch
    {
      Stop-Transcript
      Start-Transcript -Path $logFilePath -Append -Force
    }

    Set-PSDebug -Trace 0;
}


function Stop-ScriptLog
{
    Stop-Transcript
}


# =================================================================================== 
#  TSPInstallerLogging 
#  Version 0.3 - 10.10.2012 
#   
#  These functions are used to handle a central logging for the automatic SharePoint 
#  installation process: 
#   
#     - LogStartTracing                 start logging 
#     - LogEndTracing                   complete logging 
#     - LogStep                         log headline for new step 
#     - LogInfo                         log informational message 
#     - LogWarning                      log warning 
#     - LogError                        log error 
#     - LogRuntimeError                 log runtime error 
#     - LogDebug                        log debug message 
#     - LogEnableDebug                  enable debug mode for logging 
#   
#  Some of these functions log special text. If a script which uses these functions 
#  is running remotely the calling script can analyse this special text to react on 
#  it to count special messages or to log the current step of the remote script. 
# 
# History: 
#   0.1 - 21.10.2011 DHu 
#      - initial version 
# 
#   0.2 - 04.11.2011 DHu 
#      - using extended parameter definitions 
#      - using Write-Host to directly writes to host/console instead of Write-Output 
#        which writes to the pipe 
#      - adding color to the output based on the kind of output 
#      - LogRuntimeError now also loggs the calling function, line and arguments 
#      - replace transcripting and using direct writing to a file instead 
# =================================================================================== 
  
  
# =================================================================================== 
# Func: LogStartTracing 
# Desc: Initializes and starts the central logging mechanism: 
#          - setting the log file 
#          - initializing couters for warnings, errors and step numbers 
#          - logging first headline 
# =================================================================================== 
Function LogStartTracing 
{ 
	# definition of function parameters
	Param ( 
		[Parameter(Mandatory=$False, 
		HelpMessage="The log is stored on the users desktop by default. The file can be overwritten by this parameter. An existing log file is overwritten.")] 
		[String]$LogFile 
	) 

	# creating log file based on the parameter (empty parameter => store log on desktop) 
    If ($LogFile -eq "") 
    { 
		$LogTime = Get-Date -Format yyyy-MM-dd_h-mm 
		$Script:LogFile = "$env:USERPROFILE\Desktop\T-SPInstaller-$LogTime.rtf" 
    } 
    Else 
    { 
		$Script:LogFile = $LogFile 
    } 
    
    # delete file if log exists 
    If (test-path -path $Script:LogFile -pathtype leaf) 
    { 
		Remove-Item $Script:LogFile
    } 
    
    # start of the script 
	$Script:StartDate = Get-Date 

    # logging first headline 
    Clear 
    LogInfo "------------------------------------------------" -Tab 0
    LogInfo "| Automated SharePoint 2013 install script     |" -Tab 0 
    LogInfo "| Started on: $StartDate              |"  -Tab 0
    LogInfo "| (C) T-Systems 2012-2013                      |" -Tab 0
    LogInfo "------------------------------------------------" -Tab 0
    
    # no warnings or errors occured 
    $Script:CountWarnings = 0 
    $Script:CountErrors = 0 
    $Script:CountRuntimeErrors = 0 
    
    # set current step to zero 
    $Script:StepNo = 0 
    
    # debug not active yet 
    $Script:LogDebugIsEnabled = $False
	
	# set current tabulator to "no tabulator"
	$Script:LogTabCurrent = 0
} 
  
  
# =================================================================================== 
# Func: LogEndTracing 
# Desc: Initializes and starts the central logging mechanism: 
#          - setting the log file 
#          - initializing couters for warnings, errors and step numbers 
#          - logging first headline 
# =================================================================================== 
Function LogEndTracing 
{ 
	# this is the log output to show that the script reaches the normal end 
	LogInfo " " -Tab 0
	LogInfo " " -Tab 0
	LogInfo " " -Tab 0
	LogInfo "- Finished!" -Tab 0

	# end of the script 
	$Script:EndDate = Get-Date 

	# protocol of the processing 
	LogInfo "------------------------------------------------" -Tab 0
	LogInfo "| Automated SP2010 install script              |" -Tab 0
	LogInfo "| Started on:     $Script:StartDate          |" -Tab 0
	LogInfo "| Completed:      $Script:EndDate          |" -Tab 0
	LogInfo "|                                              |" -Tab 0
	LogInfo ("| Warnings:       {0,-19}          |" -f $Script:CountWarnings) -Tab 0
	LogInfo ("| Errors:         {0,-19}          |" -f $Script:CountErrors) -Tab 0
	LogInfo ("| Runtime errors: {0,-19}          |" -f $Script:CountRuntimeErrors) -Tab 0 
	LogInfo "------------------------------------------------" -Tab 0
} 
  
  
# =================================================================================== 
# Func: LogInfo 
# Desc: Logs an informational text 
# =================================================================================== 
Function LogInfo 
{ 
	# definition of function parameters
	Param ( 
		[Parameter(Mandatory=$False, 
		HelpMessage="Text to be logged")] 
		[String]$Text, 

		[Parameter(Mandatory=$False, 
		HelpMessage="Color of text which is written to the host")] 
		[string]$ForegroundColor="black", 

		[Parameter(Mandatory=$False, 
		HelpMessage="Color of background when writing the text to the host")] 
		[string]$BackgroundColor="white", 

		[Parameter(Mandatory=$False, 
		HelpMessage="Defines how many tabulators the message should be printed indented. Values from -1 to 8 can be defined. The default -1 means to use the amount of tabulator like in the previous call.")] 
		[ValidateRange(-1,8)] 
		[Int]$Tab=-1,

		[Parameter(Mandatory=$False, 
		HelpMessage="Defines how many tabulators on the last defined tabulators the message should be printed intended. Values from -1 to 8 can be defined. The default -1 means to use the amount of tabulator like in the previous call.")] 
		[ValidateRange(-1,8)] 
		[Int]$TabPlus=-1,

		[Parameter(Mandatory=$False, 
		HelpMessage="The parameter flags the text as a header of the defined level. Value from 0 to 2 can be defined. The default 0 means that the text is not treaded as a header.")] 
		[ValidateRange(0,3)] 
		[Int]$Header=0
	) 
	
	# handle header processing (empty lines above the header)
	If ($Header -ne 0)
	{
		Switch ($Header)
		{
			1
				{
					LogInfo " "
					LogInfo " "
				}
			2
				{
					LogInfo " "
				}
			3
				{
					LogInfo " "
				}
		}
	}
	
	# define the amount of tabs / spaces before the message
	If ($Tab -eq -1) 
	{
		$Tabs = $Script:LogTabCurrent
	}
	Else
	{
		$Tabs = $Tab
		$Script:LogTabCurrent = $Tab
	}
	
	# the message should be indented based on the last tabulator
	If ($TabPlus -gt 0)
	{
		$Tabs += $TabPlus
	}
	
	$Spaces = "" 
	For ($I = 1; $I -le $Tabs; $I++) 
	{ 
		$Spaces += "   "
	} 
	$Message = $($Spaces + $Text) 

	# log message 
	Write-Host $Message -BackgroundColor $BackgroundColor -ForegroundColor $ForegroundColor 
	Write-Output $Message >> $Script:LogFile 
	
	# handle header processing (underlines the text)
	If ($Header -ne 0)
	{
		Switch ($Header)
		{
			1
				{
					$Message = $("=" * $Text.Length)
					LogInfo ($Message) -BackgroundColor $BackgroundColor -ForegroundColor $ForegroundColor 
				}
			2
				{
					$Message = $("-" * $Text.Length)
					LogInfo ($Message) -BackgroundColor $BackgroundColor -ForegroundColor $ForegroundColor 
				}
		}
	}
} 
  
  
# =================================================================================== 
# Func: LogWarning 
# Desc: Logs a warning. The amount of warnings is increased and the text "WARNING: " 
#       is prepended. This text is analysed when the script is started remotely to 
#       get an overview about the processing status. 
# =================================================================================== 
Function LogWarning 
{ 
	Param ( 
		[Parameter(Mandatory=$False, 
		HelpMessage="Text to be logged")] 
		[String]$Text,

		[Parameter(Mandatory=$False, 
		HelpMessage="Defines how many tabulators the message should be printed intended. Values from -1 to 8 can be defined. The default -1 means to use the amount of tabulator like in the previous call.")] 
		[ValidateRange(-1,8)] 
		[Int]$Tab=-1,

		[Parameter(Mandatory=$False, 
		HelpMessage="Defines how many tabulators on the last defined tabulators the message should be printed intended. Values from -1 to 8 can be defined. The default -1 means to use the amount of tabulator like in the previous call.")] 
		[ValidateRange(-1,8)] 
		[Int]$TabPlus=-1,

		[Parameter(Mandatory=$False, 
		HelpMessage="The parameter flags the text as a header of the defined level. Value from 0 to 2 can be defined. The default 0 means that the text is not treaded as a header.")] 
		[ValidateRange(0,3)] 
		[Int]$Header=0
	)

	# prepend the warning tag befor logging the message 
	LogInfo ("WARNING: " + $Text) -ForegroundColor Blue -Tab $Tab -TabPlus $TabPlus -Header $Header
	$Script:CountWarnings += 1 
} 
  
  
# =================================================================================== 
# Func: LogError 
# Desc: Logs an error. The amount of errors is increased and the text "ERROR: " 
#       is prepended. This text is analysed when the script is started remotely to 
#       get an overview about the processing status. 
# =================================================================================== 
Function LogError 
{ 
	# definition of function parameters
	Param ( 
		[Parameter(Mandatory=$False, 
		HelpMessage="Text to be logged")] 
		[String]$Text,

		[Parameter(Mandatory=$False, 
		HelpMessage="Defines how many tabulators the message should be printed intended. Values from -1 to 8 can be defined. The default -1 means to use the amount of tabulator like in the previous call.")] 
		[ValidateRange(-1,8)] 
		[Int]$Tab=-1,

		[Parameter(Mandatory=$False, 
		HelpMessage="Defines how many tabulators on the last defined tabulators the message should be printed intended. Values from -1 to 8 can be defined. The default -1 means to use the amount of tabulator like in the previous call.")] 
		[ValidateRange(-1,8)] 
		[Int]$TabPlus=-1,

		[Parameter(Mandatory=$False, 
		HelpMessage="The parameter flags the text as a header of the defined level. Value from 0 to 2 can be defined. The default 0 means that the text is not treaded as a header.")] 
		[ValidateRange(0,3)] 
		[Int]$Header=0
	) 

	# prepend the error tag before logging the message 
	LogInfo $("ERROR: " + $Text) -ForegroundColor Red -Tab $Tab -TabPlus $TabPlus -Header $Header
	$Script:CountErrors += 1 
} 
  
  
# =================================================================================== 
# Func: LogRuntimeError 
# Desc: Logs an runtime error. The amount of errors is increased and the text 
#       "RUNTIME ERROR: " is prepended. This text is analysed when the script is 
#       started remotely to get an overview about the processing status. 
# =================================================================================== 
Function LogRuntimeError 
{ 
	# definition of function parameters
	Param ( 
		[Parameter(Mandatory=$False, 
		HelpMessage="The text is logged as a header before the runtime error is printed")] 
		[String]$Text, 

		[Parameter(Mandatory=$True, 
		HelpMessage="Error object which contains the error details")] 
		$ErrorObj 
	) 
	# determine calling function 
	$Function = (Get-PSCallStack)[1] 

    # logging the error also with information about the calling function 
	LogInfo " " -Tab 0
	LogInfo " " -Tab 0
	LogInfo "************************************************************************************" -ForegroundColor Red  -Tab 0
	LogInfo $($Text) -ForegroundColor Red -Tab 0
	LogInfo $(" ") -ForegroundColor Red -Tab 0
	LogInfo $("RUNTIME ERROR:") -ForegroundColor Red -Tab 0
	LogInfo $([string]$ErrorObj) -ForegroundColor Red -Tab 0
	LogInfo $(" ") -Tab 0
	LogInfo $("Calling function:") -ForegroundColor Red -Tab 0
	LogInfo $("Command:     " + $Function.Command) -ForegroundColor Red -Tab 1
	LogInfo $("Arguments:   " + $Function.Arguments) -ForegroundColor Red -Tab 1
	LogInfo $("Location:    " + $Function.Location) -ForegroundColor Red -Tab 1
	LogInfo $("Script name: " + $Function.ScriptName) -ForegroundColor Red -Tab 1
	LogInfo "************************************************************************************" -ForegroundColor Red -Tab 0
	LogInfo " " -Tab 0
	LogInfo " " -Tab 0

	# increase runtime errors 
	$Script:CountRuntimeErrors += 1 
} 
  
  
# =================================================================================== 
# Func: LogDebug 
# Desc: The defined text is just logged when the debugging is activated 
# =================================================================================== 
Function LogDebug 
{ 
	# definition of function parameters
	Param ( 
		[Parameter(Mandatory=$False, 
		HelpMessage="Text to be logged")] 
		[String]$Text,

		[Parameter(Mandatory=$False, 
		HelpMessage="Defines how many tabulators the message should be printed intended. Values from -1 to 8 can be defined. The default -1 means to use the amount of tabulator like in the previous call.")] 
		[ValidateRange(-1,8)] 
		[Int]$Tab=-1,

		[Parameter(Mandatory=$False, 
		HelpMessage="Defines how many tabulators on the last defined tabulators the message should be printed intended. Values from -1 to 8 can be defined. The default -1 means to use the amount of tabulator like in the previous call.")] 
		[ValidateRange(-1,8)] 
		[Int]$TabPlus=-1,

		[Parameter(Mandatory=$False, 
		HelpMessage="The parameter flags the text as a header of the defined level. Value from 0 to 2 can be defined. The default 0 means that the text is not treaded as a header.")] 
		[ValidateRange(0,3)] 
		[Int]$Header=0
	) 

	# just log if debugging is active 
	If ($Script:LogDebugIsEnabled) 
	{ 
		# using the central function to write the text to the console and to the log file 
		LogInfo ($Text) -ForegroundColor DarkGray -Tab $Tab -TabPlus $TabPlus -Header $Header
	} 
} 
  
  
# =================================================================================== 
# Func: LogEnableDebug 
# Desc: Enable debugging 
# =================================================================================== 
Function LogEnableDebug 
{ 
	# enable debugging 
	$Script:LogDebugIsEnabled = $True 
} 
  
  
# =================================================================================== 
# Func: LogStep 
# Desc: Logs a seperator and new headline with the next step number. The starting 
#       time and the text "STEP " plus the step number is prepended. This text is 
#       analysed when the script is started remotely to show the current processing 
#       step of the remote started script. 
# =================================================================================== 
Function LogStep 
{ 
	# definition of function parameters
	Param ( 
		[Parameter(Mandatory=$False, 
		HelpMessage="Text to be logged")] 
		[String]$Text 
	) 
	# increase the step number 
	$Script:StepNo = $Script:StepNo + 1 

	# using the central function to write the text to the console and to the log file 
	LogInfo " " -Tab 0
	LogInfo " " -Tab 0
	LogInfo "==========================================================" -Tab 0
	LogInfo $("STEP {0}: {1} (started at {2:T})" -f $Script:StepNo, $Text, (Get-Date)) -Tab 0
}