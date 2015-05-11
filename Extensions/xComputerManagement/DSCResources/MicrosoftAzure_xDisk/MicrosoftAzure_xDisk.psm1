#
# xComputer: DSC resource to initialize, partition, and format disks.
#

function Get-TargetResource
{
    param
    (
        [parameter(Mandatory)]
        [uint32] $DiskNumber,

        [string] $DriveLetter
    )

    $disk = Get-Disk -Number $DiskNumber
    $returnValue = @{
        DiskNumber = $disk.Number
        DriveLetter = $disk | Get-Partition | Where-Object { $_.DriveLetter -ne "`0" } | Select-Object -ExpandProperty DriveLetter
    }
    $returnValue
}

function Set-TargetResource
{
    param
    (
        [parameter(Mandatory)]
        [uint32] $DiskNumber,

        [string] $DriveLetter
    )

    Write-Verbose -Message "Initializing disk number '$($DiskNumber)'..."

    $disk = Get-Disk -Number $DiskNumber | Initialize-Disk -PartitionStyle GPT -PassThru
    if ($DriveLetter)
    {
        $partition = $disk | New-Partition -DriveLetter $DriveLetter -UseMaximumSize
    }
    else
    {
        $partition = $disk | New-Partition -AssignDriveLetter -UseMaximumSize
    }

    # Sometimes the disk will still be read-only after the call to New-Partition returns.
    Start-Sleep -Seconds 5

    $volume = $partition | Format-Volume -FileSystem NTFS -Confirm:$false

    Write-Verbose -Message "Successfully initialized disk number '$($DiskNumber)'."
}

function Test-TargetResource
{
    param
    (
        [parameter(Mandatory)]
        [uint32] $DiskNumber,

        [string] $DriveLetter
    )

    Write-Verbose -Message "Checking if disk number '$($DiskNumber)' is initialized..."
    $disk = Get-Disk -Number $DiskNumber
    if (-not $disk)
    {
        throw "Disk number '$($DiskNumber)' does not exist."
    }
    if ($disk.PartitionStyle -ne "RAW")
    {
        Write-Verbose "Disk number '$($DiskNumber)' has already been initialized."

        $driveLetterFromDisk = $disk | Get-Partition | Where-Object { $_.DriveLetter -ne "`0" } | Select-Object -ExpandProperty DriveLetter
        if ($DriveLetter -ne "" -and $DriveLetter -ne $driveLetterFromDisk)
        {
            throw "Disk number '$($DiskNumber)' has an unexpected drive letter. Expected: $DriveLetter. Actual: $driveLetterFromDisk."
        }
        return $true
    }
    return $false
}


Export-ModuleMember -Function *-TargetResource
