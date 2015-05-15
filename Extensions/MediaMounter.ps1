param
(
    [Parameter(Mandatory)]
    [String]$SQLFileName,

    [Parameter(Mandatory)]
    [String]$SPFileName,
    
        
    [Parameter(Mandatory)]
    [String]$MediaContainerName,
    
    [Parameter(Mandatory)]
    [String]$StorageAccountName,
    
    
    [Parameter(Mandatory)]
    [String]$StorageAccountKey,
    
)

. "$PSScriptRoot\Common.ps1"

Start-ScriptLog

import-module "C:\Program Files (x86)\Microsoft SDKs\Azure\PowerShell\ServiceManagement\Azure\Azure.psd1"
$StorageAccountName = $StorageAccountName
$StorageAccountKey = $StorageAccountKey
$destination = "e:\data\media"
$context = New-AzureStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey

Get-AzureStorageContainer -Name "sql" -Context $context | Get-AzureStorageBlob | Get-AzureStorageBlobContent -Destination $destination 

if ($SQLFileName.ToLower().EndsWith("iso"))
{
    $imagePath = $($destination + "\" + $SQLFileName)
    Mount-DiskImage $imagePath -PassThru
    $diskimage = Get-DiskImage $imagePath
    $volume = Get-Volume -DiskImage $diskimage
    copy-item "$($volume.driveletter):\" -Destination $($destination + "\sql_extracted") -Recurse
    Dismount-DiskImage $ImagePath
}

if ($SPFileName.ToLower().EndsWith("iso"))
{
    $imagePath = $($destination + "\" + $SPFileName)
    Mount-DiskImage $imagePath -PassThru
    $diskimage = Get-DiskImage $imagePath
    $volume = Get-Volume -DiskImage $diskimage
    copy-item "$($volume.driveletter):\" -Destination $($destination + "\sp_extracted")  -Recurse
    Dismount-DiskImage $ImagePath
}



Stop-ScriptLog
