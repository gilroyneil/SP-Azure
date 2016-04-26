
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

#        loginfo $("Write Config file contents to the same folder: " + $parentFolder)
#        Set-Content -Path $($parentFolder + "\" + $SPConfigSilentName) -Value $SPConfigSilent
        
      #  $SPMediaContainerName = "4297"
        
        
        
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
       

        
        Script PatchExtraFiles
        {
            GetScript  = { return 'foo'}
            TestScript = {


            $currentDate = Get-Date -format "yyyy-MMM-d-HH-mm-ss"
            $logPathPrefix = "c:\data\install\logs\"

            if ((test-path $logPathPrefix) -ne $true)
            {
                new-item $logPathPrefix -itemtype directory 
            }
            $fileName = $($logPathPrefix + "SP-ExtraFilesPatch-TEST-" + $currentDate.ToString() + ".txt")

            return $false

           # "SPMediaContainerName:" >> $fileName
          #  $using:SPMediaContainerName  >> $fileName
                

          #  if ($using:SPMediaContainerName -eq "4297")
        #    {            
        #        "RUN:" >> $fileName
       #      return $false}
        #     else
       #      {
       #         "DONT RUN:" >> $fileName
       #         return $true
       #      }
             }
            SetScript  = {
            
                $parentFolder = "E:\data\media\sppatch"
                

                $currentDate = Get-Date -format "yyyy-MMM-d-HH-mm-ss"
                $logPathPrefix = "c:\data\install\logs\"

                if ((test-path $logPathPrefix) -ne $true)
                {
                    new-item $logPathPrefix -itemtype directory 
                }
                $fileName = $($logPathPrefix + "SP-ExtraFilesPatch-SET-" + $currentDate.ToString() + ".txt")


                "Running:" >> $fileName
                "Use folder: " >> $fileName
                $parentFolder >> $fileName

                $stsMSPExists = $true
                $wssMSPExists = $true
                $stsEXEExists = $true
                $wsslocEXEExists = $true
                

        #########################################################################################################################
                    #Install the STS MSP file if it exists
                
                $stsMSP =  Get-ChildItem -Path $parentFolder -Include "*.msp" -Recurse | Where-Object {$_.Name -match "sts"}
                if ($stsMSP -ne $null)
                {            
                    $MSPLocation = $stsMSP.FullName              
                    "Found this STS.MSP file: " >> $fileName      
                    $MSPLocation >> $fileName
                }
                else
                {
                    loginfo "Cannot find MSP file"
                    $stsMSPExists = $false
                }

                if ($stsMSPExists)
                {
                    $p = start-process $MSPLocation -ArgumentList "/quiet /norestart" -Wait -PassThru
                    $p.WaitForExit()
                    $lExitCode = $p.ExitCode

                    "Exit Code (2359302 means already installed): " >> $fileName
                    $lExitCode >> $fileName
                }
                
                

        #########################################################################################################################
                    #Install the WSSMUI MSP file if it exists
                                
                $stsMSP =  Get-ChildItem -Path $parentFolder -Include "*.msp" -Recurse | Where-Object {$_.Name -match "wssmui"}
                if ($stsMSP -ne $null)
                {            
                    $MSPLocation = $stsMSP.FullName  
                
                    "Found this wssmui.MSP file: " >> $fileName      
                    $MSPLocation >> $fileName

                }
                else
                {
                    loginfo "Cannot find WSSMUI MSP file"
                    $wssMSPExists = $false
                }

                if ($stsMSPExists)
                {
                    $p = start-process $MSPLocation -ArgumentList "/quiet /norestart" -Wait -PassThru
                    $p.WaitForExit()
                    $lExitCode = $p.ExitCode

                    "Exit Code (2359302 means already installed): " >> $fileName
                    $lExitCode >> $fileName

                    if ($lExitCode -eq 0)
                    {

                        Start-Process "c:\Program Files\Common Files\Microsoft Shared\web server extensions\16\bin\PSConfig.exe" -ArgumentList " -cmd secureresources -cmd installfeatures -cmd upgrade -inplace b2b -force -wait -cmd applicationcontent -install" -Wait
                    }
                }



        #########################################################################################################################
                    #Install the STS2016 EXE file if it exists
                                
                $stsEXE =  Get-ChildItem -Path $parentFolder -Include "*.exe" -Recurse | Where-Object {$_.Name -match "sts2016"}
                if ($stsEXE -ne $null)
                {            
                    $EXELocation = $stsEXE.FullName  
                
                    "Found this sts2016.exe file: " >> $fileName      
                    $EXELocation >> $fileName

                }
                else
                {
                    loginfo "Cannot find sts2016 EXE file"
                    $stsEXEExists = $false
                }

                if ($stsEXEExists)
                {
                    $STSLogfileName = $($logPathPrefix + $stsEXE.Name + "_deploylog_" + $currentDate.ToString() + ".txt")
                    $p = start-process $EXELocation -ArgumentList "/quiet /norestart" -Wait -PassThru
                    $p.WaitForExit()
                    $lExitCode = $p.ExitCode

                    "Exit Code (2359302 means already installed): " >> $fileName
                    $lExitCode >> $fileName

                   
                }


        #########################################################################################################################
                    #Install the WSSLOC EXE file if it exists
                                
                $wsslocEXE =  Get-ChildItem -Path $parentFolder -Include "*.exe" -Recurse | Where-Object {$_.Name -match "wssloc2016"}
                if ($wsslocEXE -ne $null)
                {            
                    $EXELocation = $wsslocEXE.FullName  
                
                    "Found this wssloc2016.exe file: " >> $fileName      
                    $EXELocation >> $fileName

                }
                else
                {
                    loginfo "Cannot find wssloc2016 EXE file"
                    $wsslocEXEExists = $false
                }

                if ($wsslocEXEExists)
                {
                    $WSSLocLogfileName = $($logPathPrefix + $wsslocEXE.Name + "_deploylog_" + $currentDate.ToString() + ".txt")
                    $p = start-process $EXELocation -ArgumentList "/quiet /norestart" -Wait -PassThru
                    $p.WaitForExit()
                    $lExitCode = $p.ExitCode

                    "Exit Code (2359302 means already installed): " >> $fileName
                    $lExitCode >> $fileName

                    if ($lExitCode -eq 0)
                    {

                        Start-Process "c:\Program Files\Common Files\Microsoft Shared\web server extensions\16\bin\PSConfig.exe" -ArgumentList " -cmd secureresources -cmd installfeatures -cmd upgrade -inplace b2b -force -wait -cmd applicationcontent -install" -Wait
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
