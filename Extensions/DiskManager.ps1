
. "$PSScriptRoot\Common.ps1"

Start-ScriptLog

function change-CDRomDriveLetter
{
    $LastDriveLetter = "z"
    Get-WmiObject win32_logicaldisk -filter 'DriveType=5' | Sort-Object -property DeviceID -Descending | ForEach-Object {
        write-host "Found CDROM drive on $($_.DeviceID)"
        $a = mountvol $_.DeviceID /l
        # Get first free drive letter starting from Z: and working backwards.
        # Many scripts on the Internet recommend using the following line:
        # $UseDriveLetter = Get-ChildItem function:[d-$LastDriveLetter]: -Name | Where-Object {-not (Test-Path -Path $_)} | Sort-Object -Descending | Select-Object -First 1
        # However, if you run Test-Path on a CD-ROM or other drive letter
        # without any media, it will return False even though the drive letter
        # itself is in use. So to ensure accuracy we use the following line:
        $UseDriveLetter = Get-ChildItem function:[d-$LastDriveLetter]: -Name | Where-Object { (New-Object System.IO.DriveInfo($_)).DriveType -eq 'NoRootDirectory' } | Sort-Object -Descending | Select-Object -First 1
        If ($UseDriveLetter -ne $null -AND $UseDriveLetter -ne "") {
          write-host "$UseDriveLetter is available to use"
          write-host "Changing $($_.DeviceID) to $UseDriveLetter"
          mountvol $_.DeviceID /d
          $a = $a.Trim()
          mountvol $UseDriveLetter $a
        } else {
          write-host "No available drive letters found."
        }
      }
}

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

change-CDRomDriveLetter

configuration DiskManager
{
    Import-DscResource -ModuleName xComputerManagement

    if ($env:COMPUTERNAME.ToString().ToLower() -match "-sp")
    {

        Node $env:COMPUTERNAME
        {
            Script PowerPlan
            {
                SetScript = { Powercfg -SETACTIVE SCHEME_MIN }
                TestScript = { return ( Powercfg -getactivescheme) -like "*High Performance*" }
                GetScript = { return @{ Powercfg = ( "{0}" -f ( powercfg -getactivescheme ) ) } }
            }

            xDisk DataDisk1
            {
                DiskNumber = 2
                DriveLetter = "E"
            }

            xDisk DataDisk2
            {
                DiskNumber = 3
                DriveLetter = "F"
            }
       
          #   xDisk DataDisk3
           #  {
            #     DiskNumber = 4
            #     DriveLetter = "H"
            # }
        
            LocalConfigurationManager
            {
                CertificateId = $node.Thumbprint

            }
        }
    }
    else
    {
        Node $env:COMPUTERNAME
        {
            Script PowerPlan
            {
                SetScript = { Powercfg -SETACTIVE SCHEME_MIN }
                TestScript = { return ( Powercfg -getactivescheme) -like "*High Performance*" }
                GetScript = { return @{ Powercfg = ( "{0}" -f ( powercfg -getactivescheme ) ) } }
            }

            xDisk DataDisk1
            {
                DiskNumber = 2
                DriveLetter = "E"
            }

            xDisk DataDisk2
            {
                DiskNumber = 3
                DriveLetter = "H"
            }
                   
        
            LocalConfigurationManager
            {
                CertificateId = $node.Thumbprint

            }
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


WaitForPendingMof

DiskManager -ConfigurationData $configData -OutputPath $PSScriptRoot

$cimSessionOption = New-CimSessionOption -SkipCACheck -SkipCNCheck -UseSsl
$cimSession = New-CimSession -SessionOption $cimSessionOption -ComputerName $env:COMPUTERNAME -Port 5986

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
        Start-DscConfiguration -CimSession $cimSession -Path $PSScriptRoot -Force -Wait -Verbose *>&1 | Tee-Object -Variable output

        if (!$error)
        {
            $Stoploop = $true
        }
    }
    catch
    {
        # $_ in the catch block to include more details about the error that occured.
        Write-Warning ("ADJoin failed. Error:" + $_)

        if ($Retrycount -ge $MaximumRetryCount)
        {
            Write-Warning ("ADjoin operation failed all retries")
            $Stoploop = $true
        }
        else
        {
            $SecondsDelay = Get-TruncatedExponentialBackoffDelay -PreviousBackoffDelay $SecondsDelay -LowerBackoffBoundSeconds 10 -UpperBackoffBoundSeconds 120 -BackoffMultiplier 2
            Write-Warning -Message "An error has occurred, retrying in $SecondsDelay seconds ..."
            Start-Sleep $SecondsDelay
            $Retrycount = $Retrycount + 1
        }
    }
}
while ($Stoploop -eq $false)

CheckForPendingReboot -Output $output

Stop-ScriptLog
