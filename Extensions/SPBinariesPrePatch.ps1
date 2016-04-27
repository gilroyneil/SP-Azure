
$GLOBAL_scriptExitCode = 0

. "$PSScriptRoot\Common.ps1"

Start-ScriptLog "SP-Binaries-Pre-Patch"
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
        LogStartTracing $($logPathPrefix + "SP-Binaries-Pre-Patch" + $currentDate.ToString() + ".txt")    
        #Boiler Plate Logging setup END
        
        #new step
        LogStep "Start Pre-Reqs Instal for a Patch Build"

#        $parentFolder = "E:\data\media\SP"
#        loginfo $("Look for setup.exe in: " + $parentFolder + " and its children")
#        $exeFiles =  Get-ChildItem -Path $parentFolder -Include "*.exe" -Recurse | Where-Object {$_.Name -match "setup"}
#        if ($exeFiles -ne $null)
#        {            
#            $SetupEXELocation = $exeFiles.FullName
#            loginfo $("Found: " + $SetupEXELocation)
#            $parentFolder = $exeFiles.Directory.FullName
#        }
#        else
#        {
#            loginfo "Nothing found... throw error"
#            throw "Cannot find setup.exe"
#        }

#        loginfo $("We will run: " + $SetupEXELocation)

 #       loginfo $("Write Config file contents to the same folder: " + $parentFolder)
  #      Set-Content -Path $($parentFolder + "\" + $SPConfigSilentName) -Value $SPConfigSilent
        
        #$SPMediaContainerName = "4297"
        
     #   if ($SPMediaContainerName -eq "4297")
     #   {

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
                loginfo "Nothing found... Assume that these are PUs - i.e. just exes to run."                
            }

            loginfo $("We will run: " + $PreReqsExeLocation)
            loginfo "First check for a Windows 10 MSU file"

    #    }
    #    else
   #     {
   #         loginfo "This isnt a 4297 install, do nothing"
   #     }

        
        
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
       
        
        
        Script TestRebootPatch
        {
            GetScript  = { return 'foo'}
            TestScript = {


            $currentDate = Get-Date -format "yyyy-MMM-d-HH-mm-ss"
            $logPathPrefix = "c:\data\install\logs\"

            if ((test-path $logPathPrefix) -ne $true)
            {
                new-item $logPathPrefix -itemtype directory 
            }
            $fileName = $($logPathPrefix + "SP-PreReqsPatch-TEST-" + $currentDate.ToString() + ".txt")

return $false
     #       "SPMediaContainerName:" >> $fileName
     #       $using:SPMediaContainerName  >> $fileName
                

         #   if ($using:SPMediaContainerName -eq "4297")
       #     {            
        #        "RUN:" >> $fileName
      #       return $false}
      #       else
     #        {
    #            "DONT RUN:" >> $fileName
     #           return $true
       #      }
             }
            SetScript  = {

                $parentFolder = "E:\data\media\sppatch"
                $generalPatchesFolder = "E:\data\media\GeneralPatches"


                $currentDate = Get-Date -format "yyyy-MMM-d-HH-mm-ss"
                $logPathPrefix = "c:\data\install\logs\"

                if ((test-path $logPathPrefix) -ne $true)
                {
                    new-item $logPathPrefix -itemtype directory 
                }
                $fileName = $($logPathPrefix + "SP-PreReqsPatch-SET-" + $currentDate.ToString() + ".txt")

                $PreReqsExists = $true
                "Running:" >> $fileName
                "Use folder: " >> $fileName
                $parentFolder >> $fileName

                "Patches folder: " >> $fileName
                $generalPatchesFolder >> $fileName

    #########################################################################################################################
                #Install the Windows 10 C Runtime:

            
                $msuFile =  Get-ChildItem -Path $generalPatchesFolder -Include "*.msu" -Recurse | Where-Object {$_.Name -match "Windows8.1-KB2999226-x64"}
                if ($msuFile -ne $null)
                {            
                    $MSULocation = $msuFile.FullName  
                    
                    "Found this Windows 10 MSU file: " >> $fileName      
                    $MSULocation >> $fileName

                }
                else
                {
                    throw "Cannot find MSU file"
                }

                        $p = start-process $MSULocation -ArgumentList "/quiet /norestart" -Wait -PassThru
                        $p.WaitForExit()
                        $lExitCode = $p.ExitCode

                        "Exit Code (2359302 means already installed): " >> $fileName
                        $lExitCode >> $fileName



#########################################################################################################################
                #Install the Pre-Reqs Installer if it exists.
                
                $exeFiles =  Get-ChildItem -Path $parentFolder -Include "*.exe" -Recurse | Where-Object {$_.Name -match "prerequisiteinstaller"}
                if ($exeFiles -ne $null)
                {            
                    $PreReqsExeLocation = $exeFiles.FullName  
                    
                    "Found this pre-requisiteinstaller file: " >> $fileName      
                    $PreReqsExeLocation >> $fileName

                }
                else
                {
                    "Cannot find pre-reqsinstaller" >> $fileName
                    $PreReqsExists = $false
                }

                if ($PreReqsExists)
                {
                        $p = start-process $PreReqsExeLocation -ArgumentList "/unattended" -Wait -PassThru
                        $p.WaitForExit()
                        $lExitCode = $p.ExitCode

                        "Exit Code: " >> $fileName
                        $lExitCode >> $fileName

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
                else
                {
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
