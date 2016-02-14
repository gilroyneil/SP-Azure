param
(

    
    [String]$domainNetBiosName,

    
    [String]$DomainAdministratorUserName,

    
    [String]$DomainAdministratorPassword,

    [String]$SPMediaContainerName,

    [String]$EncryptionCertificateThumbprint
)


#$domainNetBiosName = "osazure"
#$DomainAdministratorUserName = "ngadmin"
#$DomainAdministratorPassword = "Start123"
#$SPMediaContainerName = "4297"

$GLOBAL_scriptExitCode = 0

. "$PSScriptRoot\Common.ps1"

Start-ScriptLog "SP-PreReqs-4297"
import-module storage

try
{

        #Boiler Plate Logging setup START
        $currentDate = Get-Date -format "yyyy-MMM-d-HH-mm-ss"
        $logPathPrefix = "c:\data\install\logs\"

        if ((test-path $logPathPrefix) -ne $true)
        {
            new-item $logPathPrefix -itemtype directory 
        }
        LogStartTracing $($logPathPrefix + "SP-PreReqs-4297-" + $currentDate.ToString() + ".txt")    
        #Boiler Plate Logging setup END
        
        #new step
        LogStep "Start Pre-Reqs Install (build 4297 special operations)"

        loginfo "Sleeping to start"
        sleep -Seconds 10
        loginfo "Sleep done"

        if (($SPMediaContainerName -eq "4297") -or ($SPMediaContainerName -eq "4345"))
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


        
configuration Reboots4297
{
    # Get this from TechNet Gallery
    Import-DsCResource -ModuleName xComputerManagement, xPendingReboot, xSystemSecurity
 
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
            TestScript = {


            $currentDate = Get-Date -format "yyyy-MMM-d-HH-mm-ss"
            $logPathPrefix = "c:\data\install\logs\"

            if ((test-path $logPathPrefix) -ne $true)
            {
                new-item $logPathPrefix -itemtype directory 
            }
            $fileName = $($logPathPrefix + "SP-PreReqs4297-TEST-" + $currentDate.ToString() + ".txt")


            "SPMediaContainerName:" >> $fileName
            $using:SPMediaContainerName  >> $fileName
                

            if (($using:SPMediaContainerName -eq "4297") -or ($using:SPMediaContainerName -eq "4345"))
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
            $generalPatchesFolder = "E:\data\media\GeneralPatches"


            $currentDate = Get-Date -format "yyyy-MMM-d-HH-mm-ss"
            $logPathPrefix = "c:\data\install\logs\"

            if ((test-path $logPathPrefix) -ne $true)
            {
                new-item $logPathPrefix -itemtype directory 
            }
            $fileName = $($logPathPrefix + "SP-PreReqs4297-SET-" + $currentDate.ToString() + ".txt")


            "Running:" >> $fileName
            "Use folder: " >> $fileName
            $parentFolder >> $fileName

            "Patches folder: " >> $fileName
            $generalPatchesFolder >> $fileName


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




        
        $exeFiles =  Get-ChildItem -Path $parentFolder -Include "*.exe" -Recurse | Where-Object {$_.Name -match "prerequisiteinstaller"}
        if ($exeFiles -ne $null)
        {            
            $PreReqsExeLocation = $exeFiles.FullName  
            
            "Found this pre-requisiteinstaller file: " >> $fileName      
            $PreReqsExeLocation >> $fileName

        }
        else
        {
            throw "Cannot find pre-reqsinstaller"
        }

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
        }
 
       
        # Reboot if pending
        xPendingReboot RebootCheck4297
        {
            Name = "RebootCheck4297"
        }
    }
}
 
#WaitForPendingMof


$configData = @{
        AllNodes = @(
        @{
            Nodename = $env:COMPUTERNAME
            PSDscAllowPlainTextPassword = $true
        }
        )
    }
#Set-Location "C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\1.4\Downloads\1"
 
Reboots4297 -ConfigurationData $configData


$cimSessionOption = New-CimSessionOption -SkipCACheck -SkipCNCheck -UseSsl
$cimSession = New-CimSession -SessionOption $cimSessionOption -ComputerName $env:COMPUTERNAME -Port 5986
 
Set-DscLocalConfigurationManager -CimSession $cimSession -Path .\Reboots4297 -Verbose
 
Start-DscConfiguration -CimSession $cimSession -Path .\Reboots4297 -Force -Wait -Verbose *>&1 | Tee-Object -Variable output

        
}
catch
{
    LogRuntimeError "An error occurred:" $_
    $GLOBAL_scriptExitCode = 0
     
}
finally
{
    LogEndTracing
    exit $GLOBAL_scriptExitCode
} 


Stop-ScriptLog
