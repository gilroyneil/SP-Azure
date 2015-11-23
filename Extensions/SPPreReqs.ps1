param
(

    [Parameter(Mandatory)]
    [String]$domainNetBiosName,

    [Parameter(Mandatory)]
    [String]$DomainAdministratorUserName,

    [Parameter(Mandatory)]
    [String]$DomainAdministratorPassword,

    [String]$EncryptionCertificateThumbprint
)


$GLOBAL_scriptExitCode = 0

. "$PSScriptRoot\Common.ps1"

Start-ScriptLog "SP-PreReqs"
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
        LogStartTracing $($logPathPrefix + "SP-PreReqs" + $currentDate.ToString() + ".txt")    
        #Boiler Plate Logging setup END
        
        #new step
        LogStep "Start Pre-Reqs Install"

        $parentFolder = "E:\data\media\SP"
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




        
configuration Reboots
{
    # Get this from TechNet Gallery
    Import-DsCResource -ModuleName xComputerManagement, xPendingReboot, xSystemSecurity
 
    node $env:COMPUTERNAME
    {     
        
        
        Group Administrators
        {
            Ensure = 'Present'
            GroupName = 'Administrators'
            MembersToInclude = @("$domainNetBiosName\sp-inst")
            Credential = New-Object System.Management.Automation.PSCredential ("$domainNetBiosName\$DomainAdministratorUserName", $(ConvertTo-SecureString $DomainAdministratorPassword -AsPlainText -Force))
        }

        xUAC NeverNotifyAndDisableAll 
        { 
            Setting = "NeverNotifyAndDisableAll" 
        } 
        xIEEsc DisableIEEsc 
        { 
            IsEnabled = $false 
            UserRole = "Users" 
        } 

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
             $currentDate = Get-Date -format "yyyy-MMM-d-HH-mm-ss"
            $logPathPrefix = "c:\data\install\logs\"

            if ((test-path $logPathPrefix) -ne $true)
            {
                new-item $logPathPrefix -itemtype directory 
            }
            $fileName = $($logPathPrefix + "SP-PreReqs-SET-" + $currentDate.ToString() + ".txt")


            "Running:" >> $fileName
            "Use folder: " >> $fileName
            $parentFolder >> $fileName



        
        $exeFiles =  Get-ChildItem -Path $parentFolder -Include "*.exe" -Recurse | Where-Object {$_.Name -match "prerequisiteinstaller"}
        if ($exeFiles -ne $null)
        {            
            $PreReqsExeLocation = $exeFiles.FullName        
        }
        "Pre Reqs file found: " >> $fileName
            $PreReqsExeLocation >> $fileName

            "Time now: " >> $fileName
            Get-Date -format "yyyy-MMM-d-HH-mm-ss" >> $fileName

            

            $installUser = "$using:domainNetBiosName\sp-inst"
                $installPassword = "D1sabl3d281660"
                

            "Install user:" >> $fileName
                $installUser  >> $fileName
                
                "Setup Session to remote to self:" >> $fileName
                $cred = New-Object System.Management.Automation.PSCredential ($installUser, (ConvertTo-SecureString -String $installPassword -AsPlainText -Force))
                $env:COMPUTERNAME >> $fileName

                $session = New-PSSession -ComputerName $env:COMPUTERNAME -Credential $cred -Authentication CredSSP
                $lExitCode = invoke-Command -Session $session -Verbose {                
                param($PreReqsExeLocation, $fileName) 

                




                $p = start-process $PreReqsExeLocation -ArgumentList "/unattended" -Wait -PassThru
                $p.WaitForExit()
                $lExitCode = $p.ExitCode

                $lExitCode

                 } -ArgumentList @($PreReqsExeLocation, $fileName)  -ErrorVariable Stop 


                "Exit Code: " >> $fileName
                $lExitCode >> $fileName
                 "Time now: " >> $fileName
            Get-Date -format "yyyy-MMM-d-HH-mm-ss" >> $fileName
                #powershell.exe -noprofile -file "Packages\Domain Configuration\Manager_ConfigureDCAndAccounts_MissingPieces.ps1" $xmlFinalConfigFileNoPath "All" #| Out-Null
                #LogInfo $("Exit Code: " + $lExitCode)
                
               
                if (($lExitCode -eq 3010) -or ($lExitCode -eq 1073741515) -or ($lExitCode -eq -1073741515))
                {
                    #loginfo "reboot needed"
                    "Reboot needed" >> $fileName
                    # Setting the global:DSCMachineStatus = 1 tells DSC that a reboot is required
                    $global:DSCMachineStatus = 1

                }
                else
                {
                    #loginfo "reboot not needed."
                    "Reboot not needed" >> $fileName
                    # Setting the global:DSCMachineStatus = 0 tells DSC that a reboot is NOT required
                    $global:DSCMachineStatus = 0
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


$configData = @{
        AllNodes = @(
        @{
            Nodename = $env:COMPUTERNAME
            PSDscAllowPlainTextPassword = $true
        }
        )
    }
#Set-Location "C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\1.4\Downloads\1"
 
Reboots -ConfigurationData $configData


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
