﻿
$GLOBAL_scriptExitCode = 0

. "$PSScriptRoot\Common.ps1"

Start-ScriptLog "SP-Binaries-Patch"
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
  <PIDKEY Value=""NQGJR-63HC8-XCRQH-MYVCH-3J3QR"" />
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
        LogStartTracing $($logPathPrefix + "SP-Binaries-Patch" + $currentDate.ToString() + ".txt")    
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
        
        $SPMediaContainerName = "4297"
        
        if ($SPMediaContainerName -eq "4297")
        {

            $parentFolder = "E:\data\media\sppatch"
            loginfo $("Look for prerequisiteinstaller.exe in: " + $parentFolder + " and its children")
            $exeFiles =  Get-ChildItem -Path $parentFolder -Include "*.exe" -Recurse | Where-Object {$_.Name -match "prerequisiteinstaller"}
            if ($exeFiles -ne $null)
            {            
                $PreReqsExeLocation = $exeFiles.FullName
                loginfo $("Found: " + $PreReqsExeLocation)
            }
            else
            {
                loginfo "Nothing found... throw error"
                throw "Cannot find prerequisiteinstaller.exe"
            }

            loginfo $("We will run: " + $PreReqsExeLocation)
            loginfo "First check for a Windows 10 MSU file"

        }
        else
        {
            loginfo "This isnt a 4297 install, do nothing"
        }

        
        
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
       

        
        Script 4297ExtraFiles
        {
            GetScript  = { return 'foo'}
            TestScript = {


            $currentDate = Get-Date -format "yyyy-MMM-d-HH-mm-ss"
            $logPathPrefix = "c:\data\install\logs\"

            if ((test-path $logPathPrefix) -ne $true)
            {
                new-item $logPathPrefix -itemtype directory 
            }
            $fileName = $($logPathPrefix + "SP-ExtraFiles4297-TEST-" + $currentDate.ToString() + ".txt")


            "SPMediaContainerName:" >> $fileName
            $using:SPMediaContainerName  >> $fileName
                

            if ($using:SPMediaContainerName -eq "4297")
            {            
                "RUN:" >> $fileName
             return $false}
             else
             {
                "DONT RUN:" >> $fileName
                return $true
             }
             }
            SetScript  = {
            
            $parentFolder = "E:\data\media\sppatch"
            

            $currentDate = Get-Date -format "yyyy-MMM-d-HH-mm-ss"
            $logPathPrefix = "c:\data\install\logs\"

            if ((test-path $logPathPrefix) -ne $true)
            {
                new-item $logPathPrefix -itemtype directory 
            }
            $fileName = $($logPathPrefix + "SP-ExtraFiles4297-SET-" + $currentDate.ToString() + ".txt")


            "Running:" >> $fileName
            "Use folder: " >> $fileName
            $parentFolder >> $fileName

            

            
            $stsMSP =  Get-ChildItem -Path $parentFolder -Include "*.msp" -Recurse | Where-Object {$_.Name -match "sts"}
            if ($stsMSP -ne $null)
            {            
                $MSPLocation = $stsMSP.FullName  
            
                "Found this STS.MSP file: " >> $fileName      
                $MSPLocation >> $fileName

            }
            else
            {
                throw "Cannot find MSP file"
            }

            $p = start-process $MSPLocation -ArgumentList "/quiet /norestart" -Wait -PassThru
            $p.WaitForExit()
            $lExitCode = $p.ExitCode

            "Exit Code (2359302 means already installed): " >> $fileName
            $lExitCode >> $fileName


            
            
            $stsMSP =  Get-ChildItem -Path $parentFolder -Include "*.msp" -Recurse | Where-Object {$_.Name -match "wssmui"}
            if ($stsMSP -ne $null)
            {            
                $MSPLocation = $stsMSP.FullName  
            
                "Found this wssmui.MSP file: " >> $fileName      
                $MSPLocation >> $fileName

            }
            else
            {
                throw "Cannot find MSP file"
            }

            $p = start-process $MSPLocation -ArgumentList "/quiet /norestart" -Wait -PassThru
            $p.WaitForExit()
            $lExitCode = $p.ExitCode

            "Exit Code (2359302 means already installed): " >> $fileName
            $lExitCode >> $fileName


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