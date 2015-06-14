
$GLOBAL_scriptExitCode = 0

. "$PSScriptRoot\Common.ps1"

Start-ScriptLog "SP-Binaries"
import-module storage

$SPConfigSilentName = "SPConfigCustom.xml"

$SPConfigSilent = "
<Configuration>
  <Package Id=""sts"">
    <Setting Id=""LAUNCHEDFROMSETUPSTS"" Value=""Yes"" />
  </Package>
  <Package Id=""spswfe"">
    <Setting Id=""SETUPCALLED"" Value=""1"" />
    <Setting Id=""OFFICESERVERPREMIUM"" Value=""1"" />
  </Package>
  <ARP ARPCOMMENTS=""Installed by NG"" ARPCONTACT=""Neil Gilroy"" />
  <Logging Type=""verbose"" Path=""C:\Data\Install\Logs"" Template=""SharePoint Server Setup(*).log"" />
  <Display Level=""none"" CompletionNotice=""no"" AcceptEula=""Yes""/>
  <PIDKEY Value=""N3MDM-DXR3H-JD7QH-QKKCR-BY2Y7"" />
  <Setting Id=""SERVERROLE"" Value=""APPLICATION"" />
  <Setting Id=""USINGUIINSTALLMODE"" Value=""1"" />
  <Setting Id=""SETUPTYPE"" Value=""CLEAN_INSTALL"" />
  <Setting Id=""SETUP_REBOOT"" Value=""Never"" />
<INSTALLLOCATION Value=""E:\apps\Microsoft Office Servers\15"" />
<DATADIR Value=""F:\data\Microsoft Office Servers\Data"" />
</Configuration>
"

try
{

        #Boiler Plate Logging setup START
        $currentDate = Get-Date -format "yyyy-MMM-d-HH-mm-ss"
        $logPathPrefix = "c:\data\install\logs\"

        if ((test-path $logPathPrefix) -ne $true)
        {
            new-item $logPathPrefix -itemtype directory 
        }
        LogStartTracing $($logPathPrefix + "SP-Binaries" + $currentDate.ToString() + ".txt")    
        #Boiler Plate Logging setup END
        
        #new step
        LogStep "Start Pre-Reqs Install"

        $parentFolder = "E:\data\media\SP"
        loginfo $("Look for setup.exe in: " + $parentFolder + " and its children")
        $exeFiles =  Get-ChildItem -Path $parentFolder -Include "*.exe" -Recurse | Where-Object {$_.Name -match "setup"}
        if ($exeFiles -ne $null)
        {            
            $SetupEXELocation = $exeFiles.FullName
            loginfo $("Found: " + $SetupEXELocation)
            $parentFolder = $exeFiles.Directory.FullName
        }
        else
        {
            loginfo "Nothing found... throw error"
            throw "Cannot find setup.exe"
        }

        loginfo $("We will run: " + $SetupEXELocation)

        loginfo $("Write Config file contents to the same folder: " + $parentFolder)
        Set-Content -Path $($parentFolder + "\" + $SPConfigSilentName) -Value $SPConfigSilent
        
        
configuration Reboots
{
    # Get this from TechNet Gallery
    Import-DsCResource -ModuleName xPendingReboot
 
    node $env:COMPUTERNAME
    {     
        LocalConfigurationManager
        {
            # This is false by default
            RebootNodeIfNeeded = $true
        }
       
        Script TestReboot
        {
            GetScript  = { return 'foo'}
            TestScript = { return $false}
            SetScript  = {

            $parentFolder = "E:\data\media\SP"
        
        $exeFiles =  Get-ChildItem -Path $parentFolder -Include "*.exe" -Recurse | Where-Object {$_.Name -match "setup"}
        if ($exeFiles -ne $null)
        {            
            $SetupEXELocation = $exeFiles.FullName   
            $parentFolder = $exeFiles.Directory.FullName 
            $SPConfigFile = $($parentFolder + "\" + $SPConfigSilentName)  
            
            $processArgs = $("/config " + "`"" + $SPConfigFile + "`"")
            

            $p = start-process $SetupEXELocation -ArgumentList "$processArgs" -Wait -PassThru
            $p.WaitForExit()
            $lExitCode = $p.ExitCode
            #powershell.exe -noprofile -file "Packages\Domain Configuration\Manager_ConfigureDCAndAccounts_MissingPieces.ps1" $xmlFinalConfigFileNoPath "All" #| Out-Null
            #LogInfo $("Exit Code: " + $lExitCode)
                
                
            if ($lExitCode -eq 3010)
            {
                #loginfo "reboot needed"
                # Setting the global:DSCMachineStatus = 1 tells DSC that a reboot is required
                $global:DSCMachineStatus = 1

            }
            else
            {
                #loginfo "reboot not needed."
                # Setting the global:DSCMachineStatus = 0 tells DSC that a reboot is NOT required
                $global:DSCMachineStatus = 0
            }


        }

            
 
                
            }
        }
 
        # Reboot if pending
        xPendingReboot RebootCheck1
        {
            Name = "RebootCheck1"
        }
 
    }
}
 
WaitForPendingMof

#Set-Location "C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\1.4\Downloads\1"
 
Reboots


$cimSessionOption = New-CimSessionOption -SkipCACheck -SkipCNCheck -UseSsl
$cimSession = New-CimSession -SessionOption $cimSessionOption -ComputerName $env:COMPUTERNAME -Port 5986
 
Set-DscLocalConfigurationManager -CimSession $cimSession -Path .\Reboots -Verbose
 
Start-DscConfiguration -CimSession $cimSession -Path .\Reboots -Force -Wait -Verbose *>&1 | Tee-Object -Variable output

        
}
catch
{
    LogRuntimeError "An error occurred:" $_
    $GLOBAL_scriptExitCode = 1
     
}
finally
{
    LogEndTracing
    exit $GLOBAL_scriptExitCode
} 


Stop-ScriptLog
