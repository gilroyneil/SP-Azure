
param
(
    [Parameter(Mandatory)]
    [String]$DomainName,

    [Parameter(Mandatory)]
    [String]$domainNetBiosName,

    [Parameter(Mandatory)]
    [String]$DomainAdministratorUserName,

    [Parameter(Mandatory)]
    [String]$DomainAdministratorPassword,

    [Parameter(Mandatory)]
    [String]$ServiceUserName,

    [Parameter(Mandatory)]
    [String]$ServicePassword,

    [String]$EncryptionCertificateThumbprint
)


$GLOBAL_scriptExitCode = 0

. "$PSScriptRoot\Common.ps1"

#$DomainName = "osazure.com"
#$domainNetBiosName = "osazure"
#$DomainAdministratorUserName = "ngadmin"
#$DomainAdministratorPassword = "Start123"
#$ServiceUserName = "osazure2"
#$ServicePassword = "ss"


Start-ScriptLog "Setup SQL"




if ($EncryptionCertificateThumbprint)
{
    Write-Verbose -Message "Decrypting parameters with certificate $EncryptionCertificateThumbprint..."

    $DomainAdministratorPassword = Decrypt -Thumbprint $EncryptionCertificateThumbprint -Base64EncryptedValue $DomainAdministratorPassword

    Write-Verbose -Message "Successfully decrypted parameters."
}
else
{
    Write-Verbose -Message "No encryption certificate specified. Assuming cleartext parameters."
}

configuration SQLServer2014
{
    Import-DscResource -ModuleName xComputerManagement, xSQLServer, xSystemSecurity

    Node $env:COMPUTERNAME
    {
        

        Group Administrators
        {
            Ensure = 'Present'
            GroupName = 'Administrators'
            MembersToInclude = @("$domainNetBiosName\sp-inst")
            Credential = New-Object System.Management.Automation.PSCredential ("$domainNetBiosName\$DomainAdministratorUserName", $(ConvertTo-SecureString $DomainAdministratorPassword -AsPlainText -Force))
        }

        WindowsFeature installdotNet
        {            
            Ensure = "Present"
            Name = "Net-Framework-Core"
            Source = "c:\software\sxs"
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
            
        xSQLServerSetup installSqlServer
        {

            SourcePath = "e:\data\media"
            SourceFolder = "\SW_DVD9_NTRL_SQL_Svr_Std_Ent_Dev_BI_2014_English_FPP_OEM_X19-33828"
            Features= "SQLENGINE,SSMS,ADV_SSMS"
            InstanceName="SP"
            InstanceID="SP"
            SQLSysAdminAccounts="BUILTIN\ADMINISTRATORS" 
            SQLSvcAccount= New-Object System.Management.Automation.PSCredential ("$domainNetBiosName\sp-sql", $(ConvertTo-SecureString "D1sabl3d281660" -AsPlainText -Force))
            AgtSvcAccount= New-Object System.Management.Automation.PSCredential ("$domainNetBiosName\sp-sql", $(ConvertTo-SecureString "D1sabl3d281660" -AsPlainText -Force))
            SQMReporting  = "1"
            InstallSQLDataDir="E:\Apps\SQL\"
            SQLUserDBDir= "H:\Data\Dbs\"
            SQLUserDBLogDir="H:\Data\Logs\"
            SQLTempDBDir="H:\Data\TempDb\"
            SQLTempDBLogDir="H:\Data\TempDbLog\"
            SQLBackupDir="H:\Data\Backup\"
            #PID = "YQWTX-G8T4R-QW4XX-BVH62-GP68Y"
            UpdateEnabled = "False"
            UpdateSource = "." # Must point to an existing folder, even though UpdateEnabled is set to False - otherwise it will fail
            SetupCredential = New-Object System.Management.Automation.PSCredential ("$domainNetBiosName\sp-inst", $(ConvertTo-SecureString "D1sabl3d281660" -AsPlainText -Force))

            DependsOn = "[WindowsFeature]installdotNet"
        }


        
        
        LocalConfigurationManager
        {
            CertificateId = $node.Thumbprint


        }
    }
}

if ($EncryptionCertificateThumbprint)
{
    $certificate = dir Cert:\LocalMachine\My\$EncryptionCertificateThumbprint
    $certificatePath = Join-Path -path $PSScriptRoot -childPath "EncryptionCertificate.cer"
    Export-Certificate -Cert $certificate -FilePath $certificatePath | Out-Null
    $configData = @{
        AllNodes = @(
        @{
            Nodename = $env:COMPUTERNAME
            CertificateFile = $certificatePath
            Thumbprint = $EncryptionCertificateThumbprint
        }
        )
    }
}
else
{
    $configData = @{
        AllNodes = @(
        @{
            Nodename = $env:COMPUTERNAME
            PSDscAllowPlainTextPassword = $true
        }
        )
    }
}




try
{

        #Boiler Plate Logging setup START
        $currentDate = Get-Date -format "yyyy-MMM-d-HH-mm-ss"
        $logPathPrefix = "c:\data\install\logs\"

        if ((test-path $logPathPrefix) -ne $true)
        {
            new-item $logPathPrefix -itemtype directory 
        }
        LogStartTracing $($logPathPrefix + "SetupSQL" + $currentDate.ToString() + ".txt")    
        #Boiler Plate Logging setup END
        
        #new step
        LogStep "SQL DSC Work."

loginfo "Disable Firewalls - todo make this rules"
        Get-NetFirewallProfile | Set-NetFirewallProfile -Enabled False
        loginfo "Done - firewalls disabled"

        WaitForPendingMof
        loginfo "Config about to be called"
        SQLServer2014 -ConfigurationData $configData -OutputPath $PSScriptRoot

        $cimSessionOption = New-CimSessionOption -SkipCACheck -SkipCNCheck -UseSsl
        $cimSession = New-CimSession -SessionOption $cimSessionOption -ComputerName $env:COMPUTERNAME -Port 5986

        loginfo "cimSession Created"
        if ($EncryptionCertificateThumbprint)
        {
            Set-DscLocalConfigurationManager -CimSession $cimSession -Path $PSScriptRoot -Verbose
        }

        # Run Start-DscConfiguration in a loop to make it more resilient to network outages.
        $Stoploop = $false
        $MaximumRetryCount = 5
        $Retrycount = 0
        $SecondsDelay = 0

        do
        {
            try
            {
                $error.Clear()

                Write-Verbose -Message "Attempt $Retrycount of $MaximumRetryCount ..."
                loginfo $("Attempt " + $Retrycount + " of " + $MaximumRetryCount +" ...")
                Start-DscConfiguration -CimSession $cimSession -Path $PSScriptRoot -Force -Wait -Verbose *>&1 | Tee-Object -Variable output

                if (!$error)
                {
                    $Stoploop = $true
                }
            }
            catch
            {
                # $_ in the catch block to include more details about the error that occured.
                Write-Warning ("SQL failed. Error:" + $_)
                LogError $("SQL failed. Error:" + $_)

                if ($Retrycount -ge $MaximumRetryCount)
                {
                    LogError $("SQL failed all retires")
                    $Stoploop = $true
                }
                else
                {
                    $SecondsDelay = Get-TruncatedExponentialBackoffDelay -PreviousBackoffDelay $SecondsDelay -LowerBackoffBoundSeconds 10 -UpperBackoffBoundSeconds 120 -BackoffMultiplier 2
                    loginfi $("SQL failed, retry again")
                    Start-Sleep $SecondsDelay
                    $Retrycount = $Retrycount + 1
                }
            }
        }
        while ($Stoploop -eq $false)

        loginfo "Loop done, now check for reboot"
        CheckForPendingReboot -Output $output


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
