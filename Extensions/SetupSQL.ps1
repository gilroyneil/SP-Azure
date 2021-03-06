﻿
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
    
    
    
    
     [Parameter(Mandatory)]
    [String]$sqlServiceUserName,

    [Parameter(Mandatory)]
    [String]$sqlServicePassword,
    
     [Parameter(Mandatory)]
    [String]$spInstallUserName,

    [Parameter(Mandatory)]
    [String]$spInstallPassword,
    

    [String]$EncryptionCertificateThumbprint
)



$GLOBAL_scriptExitCode = 0

. "$PSScriptRoot\Common.ps1"


$serviceType = "SP"

#$DomainName = "osazure.com"
#$domainNetBiosName = "osazure"
#$DomainAdministratorUserName = "ngadmin"
#$DomainAdministratorPassword = "Start123"
#$ServiceUserName = "osazure2"
#$ServicePassword = "ss"

#$sqlServiceUserName = "sp-sql"
#$sqlServicePassword = "D1sabl3d281660"

#$spInstallUserName = "sp-inst"
#$spInstallPassword = "D1sabl3d281660"


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

configuration SQLServer2014_SP
{
    Import-DscResource -ModuleName xComputerManagement, xSQLServer, xSystemSecurity

    Node $env:COMPUTERNAME
    {
        

        Group Administrators
        {
            Ensure = 'Present'
            GroupName = 'Administrators'
            MembersToInclude = @("$domainNetBiosName\$spInstallUserName")
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
            
        xSQLServerSetup installSqlServer_SPC
        {

            SourcePath = "e:\data\media"
            SourceFolder = "\SW_DVD9_NTRL_SQL_Svr_Std_Ent_Dev_BI_2014_English_FPP_OEM_X19-33828"
            Features= "SQLENGINE,SSMS,ADV_SSMS"
            InstanceName="SPC"
            InstanceID="SPC"
            SQLSysAdminAccounts="BUILTIN\ADMINISTRATORS" 
            SQLSvcAccount= New-Object System.Management.Automation.PSCredential ("$domainNetBiosName\$sqlServiceUserName", $(ConvertTo-SecureString "$sqlServicePassword" -AsPlainText -Force))
            AgtSvcAccount= New-Object System.Management.Automation.PSCredential ("$domainNetBiosName\$sqlServiceUserName", $(ConvertTo-SecureString "$sqlServicePassword" -AsPlainText -Force))
            SQMReporting  = "1"
            InstallSQLDataDir="E:\Apps\SQL\"
            SQLUserDBDir= "H:\Data\SPC\Dbs\"
            SQLUserDBLogDir="H:\Data\SPC\Logs\"
            SQLTempDBDir="H:\Data\SPC\TempDb\"
            SQLTempDBLogDir="H:\Data\SPC\TempDbLog\"
            SQLBackupDir="H:\Data\SPC\Backup\"
            #PID = "YQWTX-G8T4R-QW4XX-BVH62-GP68Y"
            UpdateEnabled = "False"
            UpdateSource = "." # Must point to an existing folder, even though UpdateEnabled is set to False - otherwise it will fail
            SetupCredential = New-Object System.Management.Automation.PSCredential ("$domainNetBiosName\$spInstallUserName", $(ConvertTo-SecureString "$spInstallPassword" -AsPlainText -Force))

            DependsOn = "[WindowsFeature]installdotNet"
        }



        Script SetSQLPort_SPC
        {
            GetScript  = { 
                return 'foo'
                
                
            }
            TestScript = {
            
                return $false
            }
            SetScript  = {

                    
                    $computerName = $env:COMPUTERNAME
                    $installUserName = $using:spInstallUserName
                    $installPassword = $using:spInstallPassword
                    $instanceName = 'SPC'

                    #Script work for logging. START
                    $currentDate = Get-Date -format "yyyy-MMM-d-HH-mm-ss"
                    $logPathPrefix = "c:\data\install\logs\"

                    if ((test-path $logPathPrefix) -ne $true)
                    {
                        new-item $logPathPrefix -itemtype directory 
                    }
                    $fileName = $($logPathPrefix + "SP-SETUPSQL-" + $instanceName + "-" + $currentDate.ToString() + ".txt")    
                    #Script work for logging. END

                    "Install user:" >> $fileName
                    $installUserName  >> $fileName
                    "Install User Password:" >> $fileName
                    $installPassword  >> $fileName
                    "SQL Server Instance:" >> $fileName
                    $instanceName  >> $fileName



                    $cred = New-Object System.Management.Automation.PSCredential ($installUserName, (ConvertTo-SecureString -String $installPassword -AsPlainText -Force))               
                    $session = New-PSSession -ComputerName $env:COMPUTERNAME -Credential $cred -Authentication CredSSP
                    invoke-Command -Session $session -Verbose {                                
                        $instanceName = 'SPC'
                        $portNumber = "3625"           

                        if ((test-path -path $("HKLM:SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL12." + $instanceName + "\MSSQLServer\SuperSocketNetLib\Tcp\IPAll")) -eq $True)  
                        {                                                     
                            $retValue = Set-ItemProperty -path  $("HKLM:SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL12." + $instanceName + "\MSSQLServer\SuperSocketNetLib\Tcp\IPAll") -name "TcpPort" -value $portNumber | Out-Null                                                                                                       
                            $retValue = Set-ItemProperty -path  $("HKLM:SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL12." + $instanceName + "\MSSQLServer\SuperSocketNetLib\Tcp\IPAll") -name "TcpDynamicPorts" -value "" | Out-Null 
                            $retValue = Set-ItemProperty -path  $("HKLM:SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL12." + $instanceName + "\MSSQLServer\SuperSocketNetLib\Tcp\IPAll") -name "DisplayName" -value "Any IP Address" | Out-Null 
                        } 
                        else
                        {
                            sleep 60
                                $retValue = Set-ItemProperty -path  $("HKLM:SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL12." + $instanceName + "\MSSQLServer\SuperSocketNetLib\Tcp\IPAll") -name "TcpPort" -value $portNumber | Out-Null                                                                                                       
                            $retValue = Set-ItemProperty -path  $("HKLM:SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL12." + $instanceName + "\MSSQLServer\SuperSocketNetLib\Tcp\IPAll") -name "TcpDynamicPorts" -value "" | Out-Null 
                            $retValue = Set-ItemProperty -path  $("HKLM:SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL12." + $instanceName + "\MSSQLServer\SuperSocketNetLib\Tcp\IPAll") -name "DisplayName" -value "Any IP Address" | Out-Null 

                        }       
                    } 

                    # Restart the named instance of SQL Server to enable the changes.
                    # The restart is performed in the calling batch file.
                    
                    Restart-Service $("MSSQL$" + $instanceName) -Force

              } 

              DependsOn = "[xSQLServerSetup]installSqlServer_SPC"
            }


                   
        xSQLServerSetup installSqlServer_SPO
        {

            SourcePath = "e:\data\media"
            SourceFolder = "\SW_DVD9_NTRL_SQL_Svr_Std_Ent_Dev_BI_2014_English_FPP_OEM_X19-33828"
            Features= "SQLENGINE,SSMS,ADV_SSMS"
            InstanceName="SPO"
            InstanceID="SPO"
            SQLSysAdminAccounts="BUILTIN\ADMINISTRATORS" 
            SQLSvcAccount= New-Object System.Management.Automation.PSCredential ("$domainNetBiosName\$sqlServiceUserName", $(ConvertTo-SecureString "$sqlServicePassword" -AsPlainText -Force))
            AgtSvcAccount= New-Object System.Management.Automation.PSCredential ("$domainNetBiosName\$sqlServiceUserName", $(ConvertTo-SecureString "$sqlServicePassword" -AsPlainText -Force))
            SQMReporting  = "1"
            InstallSQLDataDir="E:\Apps\SQL\"
            SQLUserDBDir= "H:\Data\SPO\Dbs\"
            SQLUserDBLogDir="H:\Data\SPO\Logs\"
            SQLTempDBDir="H:\Data\SPO\TempDb\"
            SQLTempDBLogDir="H:\Data\SPO\TempDbLog\"
            SQLBackupDir="H:\Data\SPO\Backup\"
            #PID = "YQWTX-G8T4R-QW4XX-BVH62-GP68Y"
            UpdateEnabled = "False"
            UpdateSource = "." # Must point to an existing folder, even though UpdateEnabled is set to False - otherwise it will fail
            SetupCredential = New-Object System.Management.Automation.PSCredential ("$domainNetBiosName\$spInstallUserName", $(ConvertTo-SecureString "$spInstallPassword" -AsPlainText -Force))

            DependsOn = "[WindowsFeature]installdotNet"
        }



        Script SetSQLPort_SPO
        {
            GetScript  = { 
                return 'foo'
                
                
            }
            TestScript = {
            
                return $false
            }
            SetScript  = {


                    
                    $computerName = $env:COMPUTERNAME
                    $installUserName = $using:spInstallUserName
                    $installPassword = $using:spInstallPassword
                    $instanceName = 'SPO'

                    #Script work for logging. START
                    $currentDate = Get-Date -format "yyyy-MMM-d-HH-mm-ss"
                    $logPathPrefix = "c:\data\install\logs\"

                    if ((test-path $logPathPrefix) -ne $true)
                    {
                        new-item $logPathPrefix -itemtype directory 
                    }
                    $fileName = $($logPathPrefix + "SP-SETUPSQL-" + $instanceName + "-" + $currentDate.ToString() + ".txt")    
                    #Script work for logging. END

                    "Install user:" >> $fileName
                    $installUserName  >> $fileName
                    "Install User Password:" >> $fileName
                    $installPassword  >> $fileName
                    "SQL Server Instance:" >> $fileName
                    $instanceName  >> $fileName



                    $cred = New-Object System.Management.Automation.PSCredential ($installUserName, (ConvertTo-SecureString -String $installPassword -AsPlainText -Force))                
                    $session = New-PSSession -ComputerName $env:COMPUTERNAME -Credential $cred -Authentication CredSSP
                    invoke-Command -Session $session -Verbose {                                
                        $instanceName = 'SPO'
                        $portNumber = "3627"           

                        if ((test-path -path $("HKLM:SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL12." + $instanceName + "\MSSQLServer\SuperSocketNetLib\Tcp\IPAll")) -eq $True)  
                        {                                                     
                            $retValue = Set-ItemProperty -path  $("HKLM:SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL12." + $instanceName + "\MSSQLServer\SuperSocketNetLib\Tcp\IPAll") -name "TcpPort" -value $portNumber | Out-Null                                                                                                       
                            $retValue = Set-ItemProperty -path  $("HKLM:SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL12." + $instanceName + "\MSSQLServer\SuperSocketNetLib\Tcp\IPAll") -name "TcpDynamicPorts" -value "" | Out-Null 
                            $retValue = Set-ItemProperty -path  $("HKLM:SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL12." + $instanceName + "\MSSQLServer\SuperSocketNetLib\Tcp\IPAll") -name "DisplayName" -value "Any IP Address" | Out-Null 
                        } 
                        else
                        {
                            sleep 60
                                $retValue = Set-ItemProperty -path  $("HKLM:SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL12." + $instanceName + "\MSSQLServer\SuperSocketNetLib\Tcp\IPAll") -name "TcpPort" -value $portNumber | Out-Null                                                                                                       
                            $retValue = Set-ItemProperty -path  $("HKLM:SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL12." + $instanceName + "\MSSQLServer\SuperSocketNetLib\Tcp\IPAll") -name "TcpDynamicPorts" -value "" | Out-Null 
                            $retValue = Set-ItemProperty -path  $("HKLM:SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL12." + $instanceName + "\MSSQLServer\SuperSocketNetLib\Tcp\IPAll") -name "DisplayName" -value "Any IP Address" | Out-Null 

                        }       
                    } 

                    # Restart the named instance of SQL Server to enable the changes.
                    # The restart is performed in the calling batch file.
                    
                    Restart-Service $("MSSQL$" + $instanceName) -Force

              } 

              DependsOn = "[xSQLServerSetup]installSqlServer_SPO"
            }
        


               
        xSQLServerSetup installSqlServer_SPS
        {

            SourcePath = "e:\data\media"
            SourceFolder = "\SW_DVD9_NTRL_SQL_Svr_Std_Ent_Dev_BI_2014_English_FPP_OEM_X19-33828"
            Features= "SQLENGINE,SSMS,ADV_SSMS"
            InstanceName="SPS"
            InstanceID="SPS"
            SQLSysAdminAccounts="BUILTIN\ADMINISTRATORS" 
            SQLSvcAccount= New-Object System.Management.Automation.PSCredential ("$domainNetBiosName\$sqlServiceUserName", $(ConvertTo-SecureString "$sqlServicePassword" -AsPlainText -Force))
            AgtSvcAccount= New-Object System.Management.Automation.PSCredential ("$domainNetBiosName\$sqlServiceUserName", $(ConvertTo-SecureString "$sqlServicePassword" -AsPlainText -Force))
            SQMReporting  = "1"
            InstallSQLDataDir="E:\Apps\SQL\"
            SQLUserDBDir= "H:\Data\SPS\Dbs\"
            SQLUserDBLogDir="H:\Data\SPS\Logs\"
            SQLTempDBDir="H:\Data\SPS\TempDb\"
            SQLTempDBLogDir="H:\Data\SPS\TempDbLog\"
            SQLBackupDir="H:\Data\SPS\Backup\"
            #PID = "YQWTX-G8T4R-QW4XX-BVH62-GP68Y"
            UpdateEnabled = "False"
            UpdateSource = "." # Must point to an existing folder, even though UpdateEnabled is set to False - otherwise it will fail
            SetupCredential = New-Object System.Management.Automation.PSCredential ("$domainNetBiosName\$spInstallUserName", $(ConvertTo-SecureString "$spInstallPassword" -AsPlainText -Force))

            DependsOn = "[WindowsFeature]installdotNet"
        }



        Script SetSQLPort_SPS
        {
            GetScript  = { 
                return 'foo'
                
                
            }
            TestScript = {
            
                return $false
            }
            SetScript  = {


                    $computerName = $env:COMPUTERNAME
                    $installUserName = $using:spInstallUserName
                    $installPassword = $using:spInstallPassword
                    $instanceName = 'SPS'

                    #Script work for logging. START
                    $currentDate = Get-Date -format "yyyy-MMM-d-HH-mm-ss"
                    $logPathPrefix = "c:\data\install\logs\"

                    if ((test-path $logPathPrefix) -ne $true)
                    {
                        new-item $logPathPrefix -itemtype directory 
                    }
                    $fileName = $($logPathPrefix + "SP-SETUPSQL-" + $instanceName + "-" + $currentDate.ToString() + ".txt")    
                    #Script work for logging. END

                    "Install user:" >> $fileName
                    $installUserName  >> $fileName
                    "Install User Password:" >> $fileName
                    $installPassword  >> $fileName
                    "SQL Server Instance:" >> $fileName
                    $instanceName  >> $fileName



                    $cred = New-Object System.Management.Automation.PSCredential ($installUserName, (ConvertTo-SecureString -String $installPassword -AsPlainText -Force))                
                    $session = New-PSSession -ComputerName $env:COMPUTERNAME -Credential $cred -Authentication CredSSP
                    invoke-Command -Session $session -Verbose {                                
                        $instanceName = 'SPS'
                        $portNumber = "3628"           

                        if ((test-path -path $("HKLM:SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL12." + $instanceName + "\MSSQLServer\SuperSocketNetLib\Tcp\IPAll")) -eq $True)  
                        {                                                     
                            $retValue = Set-ItemProperty -path  $("HKLM:SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL12." + $instanceName + "\MSSQLServer\SuperSocketNetLib\Tcp\IPAll") -name "TcpPort" -value $portNumber | Out-Null                                                                                                       
                            $retValue = Set-ItemProperty -path  $("HKLM:SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL12." + $instanceName + "\MSSQLServer\SuperSocketNetLib\Tcp\IPAll") -name "TcpDynamicPorts" -value "" | Out-Null 
                            $retValue = Set-ItemProperty -path  $("HKLM:SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL12." + $instanceName + "\MSSQLServer\SuperSocketNetLib\Tcp\IPAll") -name "DisplayName" -value "Any IP Address" | Out-Null 
                        } 
                        else
                        {
                            sleep 60
                                $retValue = Set-ItemProperty -path  $("HKLM:SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL12." + $instanceName + "\MSSQLServer\SuperSocketNetLib\Tcp\IPAll") -name "TcpPort" -value $portNumber | Out-Null                                                                                                       
                            $retValue = Set-ItemProperty -path  $("HKLM:SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL12." + $instanceName + "\MSSQLServer\SuperSocketNetLib\Tcp\IPAll") -name "TcpDynamicPorts" -value "" | Out-Null 
                            $retValue = Set-ItemProperty -path  $("HKLM:SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL12." + $instanceName + "\MSSQLServer\SuperSocketNetLib\Tcp\IPAll") -name "DisplayName" -value "Any IP Address" | Out-Null 

                        }       
                    } 

                    # Restart the named instance of SQL Server to enable the changes.
                    # The restart is performed in the calling batch file.
                    
                    Restart-Service $("MSSQL$" + $instanceName) -Force

              } 

              DependsOn = "[xSQLServerSetup]installSqlServer_SPS"
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
        loginfo $("Service Type: " + $serviceType)
        if ($serviceType -eq "SP")
        {
            SQLServer2014_SP -ConfigurationData $configData -OutputPath $PSScriptRoot
        }
        else
        {
            loginfo "TODO"
        }

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
