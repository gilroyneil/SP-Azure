﻿param
(
        
    [Parameter(Mandatory)]
    [String]$SQLMediaContainerName,
    
    
    [Parameter(Mandatory)]
    [String]$SPMediaContainerName,
    
      [Parameter(Mandatory)]
    [String]$BuildScriptsContainerName,
    
      [Parameter(Mandatory)]
    [String]$GeneralMediaContainerName,
    
    
    
    
    [Parameter(Mandatory)]
    [String]$StorageAccountName,
    
    
    [Parameter(Mandatory)]
    [String]$StorageAccountKey
    
)

$GLOBAL_scriptExitCode = 0

. "$PSScriptRoot\Common.ps1"

Start-ScriptLog "MediaMounter"
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
        LogStartTracing $($logPathPrefix + "MediaMounter" + $currentDate.ToString() + ".txt")    
        #Boiler Plate Logging setup END
        
        #new step
        LogStep "Storage Account Work"

        import-module "C:\Program Files (x86)\Microsoft SDKs\Azure\PowerShell\ServiceManagement\Azure\Azure.psd1"
        $StorageAccountName = $StorageAccountName
        $StorageAccountKey = $StorageAccountKey
        $destination = "e:\data\media"
        $destinationSP = "e:\data\media\sp"
        $destinationGeneralMedia = "e:\data\media"
        $destinationBuildScripts = "e:\data\install"
            
      #  $StorageAccountName = "armstorageacc"
      #  $StorageAccountKey = "tU0SUMg2+3RRrEt7rkTpOwun/OAwCedpI7kRDDCuuOiUZfef9hOhTHIDFoySdPp0Iyhmw5GTZC+f6WHeF+OYZg=="
      #  $MediaContainerName = "media"

        if ((test-path $destination) -ne $true)
        {
            New-Item -Path $destination -ItemType directory
        }

        loginfo $("Storage Account Name: " + $StorageAccountName)
        loginfo $("Storage Account Key: " + $StorageAccountKey)
        loginfo $("SQL Media Container Name: " + $SQLMediaContainerName)
        loginfo $("SP Media Container Name: " + $SPMediaContainerName)
        loginfo $("Build Scripts Container Name: " + $BuildScriptsContainerName)
        loginfo $("General Media Container Name: " + $GeneralMediaContainerName)

        $context = New-AzureStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey
        loginfo "Download the Build Scripts"
        Get-AzureStorageContainer -Name $BuildScriptsContainerName -Context $context | Get-AzureStorageBlob | Get-AzureStorageBlobContent -Destination $destinationBuildScripts -force
        
        loginfo "Download the General Media"
        Get-AzureStorageContainer -Name $GeneralMediaContainerName -Context $context | Get-AzureStorageBlob | Get-AzureStorageBlobContent -Destination $destinationGeneralMedia -force
        
        
        loginfo "Download the SQL Media"
        Get-AzureStorageContainer -Name $SQLMediaContainerName -Context $context | Get-AzureStorageBlob | Get-AzureStorageBlobContent -Destination $destination -force
        loginfo "Download the SP Media"
        Get-AzureStorageContainer -Name $SPMediaContainerName -Context $context | Get-AzureStorageBlob | Get-AzureStorageBlobContent -Destination $destination -force

    
        logstep "ZIP Extract"
        [System.Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.FileSystem")
        $zipFiles = Get-ChildItem -Path $destination -Include "*.zip" -Recurse
        foreach ($zip in $zipFiles)
        {
            $fileName = $zip.Name
            loginfo $("ZIP found: " + $fileName)
            $fileNameBase = $zip.BaseName
            $fileNameFull = $zip.FullName
            loginfo $("About to extract file: " + $fileNameFull + " to folder: " + $destinationSP)           
            [System.IO.Compression.ZipFile]::ExtractToDirectory($fileNameFull, $destinationSP)
            loginfo "Extracted"

        }

        LogStep "ISO Mount"
        $isoFiles = Get-ChildItem -Path $destination -Include "*.iso" -Recurse
        foreach ($iso in $isoFiles)
        {
            $fileName = $iso.Name
            loginfo $("ISO found: " + $fileName)
            $fileNameBase = $iso.BaseName
            $imagePath = $($destination + "\" + $fileName)
            loginfo $("About to mount: " + $imagePath)
            Mount-DiskImage $imagePath -PassThru -ErrorAction Stop
            loginfo "Mounted"
            $diskimage = Get-DiskImage $imagePath
            $volume = Get-Volume -DiskImage $diskimage
            loginfo "Volume obtained. About to copy"
            $source = $($volume.driveletter + ":\*")
            $destination = $($destination + "\" + $fileNameBase)
            xcopy $source $destination /s /i
            #copy-item -Path $source -Destination $destination -Recurse -Container
            loginfo "Copied."
            Dismount-DiskImage $ImagePath
            loginfo "Dismount"

        }


        
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

Start-Sleep -Seconds 5
Restart-Computer -Force

Stop-ScriptLog
