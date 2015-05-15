﻿param
(
        
    [Parameter(Mandatory)]
    [String]$MediaContainerName,
    
    [Parameter(Mandatory)]
    [String]$StorageAccountName,
    
    
    [Parameter(Mandatory)]
    [String]$StorageAccountKey
    
)


. "$PSScriptRoot\Common.ps1"

Start-ScriptLog

import-module "C:\Program Files (x86)\Microsoft SDKs\Azure\PowerShell\ServiceManagement\Azure\Azure.psd1"
$StorageAccountName = $StorageAccountName
$StorageAccountKey = $StorageAccountKey
$destination = "e:\data\media"

$StorageAccountName = "armstorageacc"
$StorageAccountKey = "tU0SUMg2+3RRrEt7rkTpOwun/OAwCedpI7kRDDCuuOiUZfef9hOhTHIDFoySdPp0Iyhmw5GTZC+f6WHeF+OYZg=="
$MediaContainerName = "media"

if ((test-path $destination) -ne $true)
{
    New-Item -Path $destination -ItemType directory
}


$context = New-AzureStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey
Get-AzureStorageContainer -Name $MediaContainerName -Context $context | Get-AzureStorageBlob | Get-AzureStorageBlobContent -Destination $destination 


$isoFiles = Get-ChildItem -Path $destination -Include "*.iso" -Recurse
foreach ($iso in $isoFiles)
{
    $fileName = $iso.Name
    $fileNameBase = $iso.BaseName
    $imagePath = $($destination + "\" + $fileName)
    Mount-DiskImage $imagePath -PassThru
    $diskimage = Get-DiskImage $imagePath
    $volume = Get-Volume -DiskImage $diskimage
    copy-item "$($volume.driveletter):\" -Destination $($destination + "\" + $fileNameBase) -Recurse
    Dismount-DiskImage $ImagePath


}



Stop-ScriptLog
