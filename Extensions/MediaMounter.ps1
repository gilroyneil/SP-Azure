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
$SQLFileName =  "SW_DVD9_NTRL_SQL_Svr_Std_Ent_Dev_BI_2014_English_FPP_OEM_X19-33828.ISO"
$SPFileName = "GU32_TAP_16.0.4021.1203.zip"

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
