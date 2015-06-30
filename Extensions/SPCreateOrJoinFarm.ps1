﻿param
(

    [Parameter(Mandatory)]
    [String]$domainNetBiosName,

    [Parameter(Mandatory)]
    [String]$DomainAdministratorUserName,

    [Parameter(Mandatory)]
    [String]$DomainAdministratorPassword,

     [Parameter(Mandatory)]
    [String]$serviceName,

     [Parameter(Mandatory)]
    [String]$SQLServerInstance,

    [Parameter(Mandatory)]
    [String]$ServerRole,

    [Parameter(Mandatory)]
    [String]$FarmAdministratorUserName,
    [Parameter(Mandatory)]
    [String]$FarmAdministratorPassword,

    [Parameter(Mandatory)]
    [String]$InstallAdministratorUserName,

    [Parameter(Mandatory)]
    [String]$InstallAdministratorPassword,


    [String]$EncryptionCertificateThumbprint
)


$GLOBAL_scriptExitCode = 0

. "$PSScriptRoot\Common.ps1"

Start-ScriptLog "SP-FarmCreateOrJoin"


try
{

        #Boiler Plate Logging setup START
        $currentDate = Get-Date -format "yyyy-MMM-d-HH-mm-ss"
        $logPathPrefix = "c:\data\install\logs\"

        if ((test-path $logPathPrefix) -ne $true)
        {
            new-item $logPathPrefix -itemtype directory 
        }
        LogStartTracing $($logPathPrefix + "SP-FarmCreateOrJoin" + $currentDate.ToString() + ".txt")    
        #Boiler Plate Logging setup END
        
        #new step
        LogStep "Start SPFarm Create Or Join"

       



        
configuration CreateFarm
{
    # Get this from TechNet Gallery
    Import-DsCResource -ModuleName xComputerManagement
 
    node $env:COMPUTERNAME
    {     
        LocalConfigurationManager
        {
            # This is false by default
            RebootNodeIfNeeded = $true
        }
       
        Script CreateFarm
        {
            GetScript  = { 
                return 'foo'
                
                
            }
            TestScript = {
            
                #Script work for logging. START
                $currentDate = Get-Date -format "yyyy-MMM-d-HH-mm-ss"
                $logPathPrefix = "c:\data\install\logs\"

                if ((test-path $logPathPrefix) -ne $true)
                {
                    new-item $logPathPrefix -itemtype directory 
                }
                $fileName = $($logPathPrefix + "SP-FarmCreateOrJoin-Get-" + $currentDate.ToString() + ".txt")    
                #Script work for logging. END

                "In Test Script of CreateFarm" >> $fileName
                $using:domainNetBiosName >> $fileName

                "Check Registry Key: HKLM:\SOFTWARE\Microsoft\Shared Tools\Web Server Extensions\16.0\Secure\ConfigDB" >> $fileName
                $retVal = $false
                $configDB = (Get-Item -Path "HKLM:\SOFTWARE\Microsoft\Shared Tools\Web Server Extensions\16.0\Secure\ConfigDB" -ErrorAction SilentlyContinue)
                if ($configDB -ne $null)
                {
                    "Key value found, farm must exist" >> $fileName
                    $retVal = $true
                }
                else
                {
                    "Key value not found - Try and create a farm." >> $fileName
                }
                return $retVal
            
            
            }
            SetScript  = {


                #Script work for logging. START
                $currentDate = Get-Date -format "yyyy-MMM-d-HH-mm-ss"
                $logPathPrefix = "c:\data\install\logs\"

                if ((test-path $logPathPrefix) -ne $true)
                {
                    new-item $logPathPrefix -itemtype directory 
                }
                $fileName = $($logPathPrefix + "SP-FarmCreateOrJoin-Set-" + $currentDate.ToString() + ".txt")    
                #Script work for logging. END


                Add-PSSnapin Microsoft.SharePoint.PowerShell
                $ConfigDBName = "TAP_Config"
                $CAAdminDBName = "TAP_CAContent"
                $passphrase = "D1sabl3d281660"
                $ConfigDBAlias = "osazure3-sql0\sp"

                $serverRole = "WebFrontEnd"
                $farmAdminUser = "osazure\sp-inst"
                $farmAdminPassword = "D1sabl3d281660"

                $installUser = "osazure\sp-inst"
                $installPassword = "D1sabl3d281660"


            $cred = New-Object System.Management.Automation.PSCredential ($installUser, (ConvertTo-SecureString -String $installPassword -AsPlainText -Force))
            write-verbose $env:COMPUTERNAME
            $session = New-PSSession -ComputerName $env:COMPUTERNAME -Credential $cred -Authentication CredSSP
            invoke-Command -Session $session -Verbose {
            #invoke-Command -ComputerName $env:COMPUTERNAME -Credential $cred -Verbose {

            $currentDate = Get-Date -format "yyyy-MMM-d-HH-mm-ss"
        $logPathPrefix = "c:\data\install\logs\"

        if ((test-path $logPathPrefix) -ne $true)
        {
            new-item $logPathPrefix -itemtype directory 
        }
        LogStartTracing $($logPathPrefix + "SP-FarmCreateOrJoin-Set" + $currentDate.ToString() + ".txt")    
        #Boiler Plate Logging setup END
        
        #new step
        LogStep "Start SPFarm Create Or Join"

            Add-PSSnapin Microsoft.SharePoint.PowerShell
                    $ConfigDBName = "TAP_Config"
                    $CAAdminDBName = "TAP_CAContent"
                    $passphrase = "D1sabl3d281660"
                    $ConfigDBAlias = "osazure3-sql0\sp"

                    $serverRole = "WebFrontEnd"
                    $farmAdminUser = "osazure\sp-inst"
                    $farmAdminPassword = "D1sabl3d281660"

                    $installUser = "osazure\sp-inst"
                    $installPassword = "D1sabl3d281660"
               

                $secFarmAdminPassword = ConvertTo-SecureString $farmAdminPassword -AsPlaintext -Force 
                    $FarmAccountCredentials = New-Object System.Management.Automation.PsCredential $farmAdminUser,$secFarmAdminPassword

                    $farmExists = $true
                    $connectFarm = Connect-SPConfigurationDatabase -DatabaseName $ConfigDBName  -DatabaseServer $ConfigDBAlias -LocalServerRole $serverRole  -Passphrase (ConvertTo-SecureString $passphrase  -AsPlainText -Force   )
                    If (-not $?)
                    {
                        #Farm doesnt exist yet - so we need to create it.                        
                        New-SPConfigurationDatabase -DatabaseServer  $ConfigDBAlias -DatabaseName $ConfigDBName -LocalServerRole $serverRole -Passphrase (ConvertTo-SecureString $passphrase  -AsPlainText -Force) -AdministrationContentDatabaseName $CAAdminDBName -FarmCredentials $FarmAccountCredentials
                        Install-SPHelpCollection -All
                        Initialize-SPResourceSecurity
                        Install-SPService
                        Install-SPFeature -AllExistingFeatures
                        New-SPCentralAdministration -Port 8888 -WindowsAuthProvider NTLM
                        Install-SPApplicationContent

                    }
                    else
                    {
                        Install-SPHelpCollection -All
                        Initialize-SPResourceSecurity
                        Install-SPService
                        Install-SPFeature -AllExistingFeatures
                    }
            }

                      

      }
                    
            
        }
 
 
    }
}
 
WaitForPendingMof

#Set-Location "C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\1.4\Downloads\1"
 $configData = @{
        AllNodes = @(
        @{
            Nodename = $env:COMPUTERNAME
            Value1 = "aa"
            
        }
        )
    }

CreateFarm -ConfigurationData $configData


$cimSessionOption = New-CimSessionOption -SkipCACheck -SkipCNCheck -UseSsl
$cimSession = New-CimSession -SessionOption $cimSessionOption -ComputerName $env:COMPUTERNAME -Port 5986
 
Set-DscLocalConfigurationManager -CimSession $cimSession -Path .\CreateFarm -Verbose
 
Start-DscConfiguration -CimSession $cimSession -Path .\CreateFarm -Force -Wait -Verbose *>&1 | Tee-Object -Variable output

        
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
