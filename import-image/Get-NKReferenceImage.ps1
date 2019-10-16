#---------------------------------------------------------------------------------
# Function:         Get-NKReferenceImage.ps1
# Description:      Download reference image from central repository
# Author:           Arjan Bakker
#---------------------------------------------------------------------------------
# <date> - <version> - <author>: <changes>
# 05-14-2018 - version 1.0 - Arjan Bakker: Initial version
# 06-06-2018 - version 1.1 - Arjan Bakker: Script will now also work on machines with PowerShell 3 and 4. When a PowerShell version older than version 5 is discovered or when module "Azure.Storage" is not present, REST API will be used.
# 06-07-2018 - version 1.2 - Arjan Bakker: Changed the function to a working script. SAS token and Storageaccount no longer need to be specified when running the script.
#                                          Both variables still can be provided when running this script, e.g. when downloading files from another storage account or when the SAS token has expired and a new one is required.
#                                          Running the script without any variables (. \Get-NKReferenceImage.ps1) will download the Windows 2012 R2 WIM file by default from the central repository in Azure
#                                          Changed method of detecting presence of the Azure.Storage module
# 06-12-2018 - version 1.3 - Arjan Bakker: Added container name as a (non-mandatory) variable in case the container name is changed in future Storage Account location.
#                                          Changed search method so that when only 1 image is added to the storage it can be found and used with RestAPI (this was not working in previous version)
# 07-06-2018 - version 1.4 - Arjan Bakker: Added switches for using BitsTransfer asynchronous and with high prio. -Async will set the download to asynchronous and -HighPrio will set the download to -Foreground
#                                          The HighPrio switch will also use full bandwidth when using AzureRM to download the requested image.
# 07-11-2018 - version 1.5 - Arjan Bakker: Added try..catch around the asynchronous bits transfer and added a check before the complete-bitstransfer command is launched
#                                          to prevent the ongoing download process to be stopped when some outage has occured.
#                                          Not using the invoke-webrequest download method any longer
# 09-06-2018 - version 1.6 - Arjan Bakker: Script is now creating a Custom PSObject when ready. The PSObject holds information that can be used by the calling script. ImageName, ImagePath, ImageResult
#                                          Content in $OS variable is converted to all upper case since the search in Azure Storage is case sensitive
#                                          Replace "write-output" with "Write-Verbose -Verbose" to prevent too much output to custom psobject
# 10-23-2018 - version 1.7 - Arjan Bakker: Small change to make sure the search for WIM file is added to an Array (like the other searches).
# 02-08-2019 - version 1.8 - Arjan Bakker: Added Windows 10 Enterprise Edition version 1803 (W10EE1803) to the list of possible Operating System version to download
#                                          Changed W10EE to W10EE1703
#                                          Changed the method of acquiring the SAS token for the storage account. Only people with access to the storage account can now get the SAS token using this script.
#                                          When the person downloading the file does not have the correct access right, they will have to obtain the SAS token first and use the SAS token with the commandline switch '-SasToken'
#                                          Replace "Write-Verbose -Verbose" with "Write-Output". Issue with too much output in custom psobject has been solved by using the pscustomobject in another way
# 02-26-2019 - version 1.9 - Arjan Bakker: Fixed issue with setting TLS to 1.2 on older PowerShell versions (4)
#                                          Added switch to create a SAS token that can be used on a PowerShell 4 server where AzureRM modules are not working
#                                          Fixed issue where the script does not automatically select the proper download method
#---------------------------------------------------------------------------------
#Requires -Version 3.0

<#
.Synopsis
    Get-NKReferenceImage
.DESCRIPTION
    Get latest reference image from central repository (Azure Storage Account)
.EXAMPLE
    Get-NKReferenceImage -OS "W2K12R2SE" -ImageType "WIM" -DestinationFolder "D:\ReferenceImages"
    Request Azure credentials and then connect to default storage account, get the latest Windows 2012 R2 WIM file and download this file to folder "D:\ReferenceImages"
.EXAMPLE
    Get-NKReferenceImage -OS "W2K16SE" -ImageType "VHDX" -DestinationFolder "D:\ReferenceImages"
    Request Azure credentials and then connect to default storage account, get the latest Windows 2016 VHDX file and download this file to folder "D:\ReferenceImages"
.EXAMPLE
    Get-NKReferenceImage -SasToken "?sv=2017-04-17&ss=bt&srt=sco&sp=rwdlacu&se=2020-01-15T22:15:13Z&st=2018-01-14T14:15:13Z&spr=https&sig=EXAMPLE" -StorageAccountName "p5filesstdsa01" -OS "W2K12R2SE" -ImageType "WIM" -DestinationFolder "D:\ReferenceImages"
    Connect to storage account 'p5filesstdsa01' using the supplied SasToken, get the latest Windows 2012 R2 WIM file and download this file to folder "D:\ReferenceImages"
.EXAMPLE
    Get-NKReferenceImage -SasToken "?sv=2017-04-17&ss=bt&srt=sco&sp=rwdlacu&se=2020-01-15T22:15:13Z&st=2018-01-14T14:15:13Z&spr=https&sig=EXAMPLE" -StorageAccountName "p5filesstdsa01" -OS "W2K16SE" -ImageType "VHDX" -DestinationFolder "D:\ReferenceImages"
    Connect to storage account 'p5filesstdsa01' using the supplied SasToken, get the latest Windows 2016 SE VHDX file and download this file to folder "D:\ReferenceImages"
.EXAMPLE
    Get-NKReferenceImage -SasToken "?sv=2017-04-17&ss=bt&srt=sco&sp=rwdlacu&se=2020-01-15T22:15:13Z&st=2018-01-14T14:15:13Z&spr=https&sig=EXAMPLE" -StorageAccountName "p5filesstdsa01" -OS "W2K16CORE" -ImageType "OVF" -DestinationFolder "D:\ReferenceImages"
    Connect to storage account 'p5filesstdsa01' using the supplied SasToken, get the latest Windows 2016 CORE OVF files and download these files to folder "D:\ReferenceImages"
    OVF download will get the .OVF .MF and .VMDK files
.EXAMPLE
    Get-NKReferenceImage -CreateSAStoken

.NOTES
    This script now also works when used on PowerShell 3 and 4
    Azure.Profile module is required if no SAS token is supplied
    Azure.Storage module or Azcopy is recommended when running this script in PowerShell 5 or later. Download and install the Azure module using:
    Find-Module -Name Azure.Storage | Install-module

    Download AzCopy from: https://aka.ms/downloadazcopy

    More information can be found at: https://confluence.nike.com/display/WPEE/Manual+-+Download+Windows+reference+image
#>
[Cmdletbinding(DefaultParameterSetName = '__default')]
Param
(
    [parameter(mandatory = $false, ParameterSetName = '__createsastoken')]
    [switch]$CreateSasToken,

    [parameter(mandatory = $false, ParameterSetName = '__default')]
    [parameter(mandatory = $false, ParameterSetName = '__bits')]
    [parameter(mandatory = $false, ParameterSetName = '__azcopy')]
    [string]$SasToken = "",

    [parameter(mandatory = $false, ParameterSetName = '__default')]
    [parameter(mandatory = $false, ParameterSetName = '__bits')]
    [parameter(mandatory = $false, ParameterSetName = '__azcopy')]
    [object]$Credential = "",
    
    [parameter(mandatory = $false, ParameterSetName = '__default')]
    [parameter(mandatory = $false, ParameterSetName = '__bits')]
    [parameter(mandatory = $false, ParameterSetName = '__azcopy')]
    [parameter(mandatory = $false, ParameterSetName = '__createsastoken')]
    [string]$StorageAccountName = "p5filesstdsa01",
    
    [parameter(mandatory = $false, ParameterSetName = '__default')]
    [parameter(mandatory = $false, ParameterSetName = '__bits')]
    [parameter(mandatory = $false, ParameterSetName = '__azcopy')]
    [parameter(mandatory = $false, ParameterSetName = '__createsastoken')]
    [string]$Container = "referenceimages",
    
    [parameter(mandatory = $false, ParameterSetName = '__default')]
    [parameter(mandatory = $false, ParameterSetName = '__bits')]
    [parameter(mandatory = $false, ParameterSetName = '__azcopy')]
    [ValidateSet("W2K12R2SE", "W2K16SE", "W2K16CORE", "W10EE", "W10EE1703", "W10EE1803")]
    [string]$OS = "W2K12R2SE",
    
    [parameter(mandatory = $false, ParameterSetName = '__default')]
    [parameter(mandatory = $false, ParameterSetName = '__bits')]
    [parameter(mandatory = $false, ParameterSetName = '__azcopy')]
    [ValidateSet("OVF", "VHD", "VHDX", "WIM")]
    [string]$ImageType = "WIM",
    
    [parameter(mandatory = $false, ParameterSetName = '__default')]
    [parameter(mandatory = $false, ParameterSetName = '__bits')]
    [parameter(mandatory = $false, ParameterSetName = '__azcopy')]
    [string]$Destinationfolder = $(get-location).Path,
    
    [Alias("ForceRestAPI")]
    [parameter(mandatory = $false, ParameterSetName = '__bits')]
    [switch]$UseBitsDownload,
    
    [parameter(mandatory = $false, ParameterSetName = '__bits')]
    [switch]$ASync,
    
    [parameter(mandatory = $false, ParameterSetName = '__azcopy')]
    [switch]$UseAzCopy,
    
    [parameter(mandatory = $false, ParameterSetName = '__default')]
    [parameter(mandatory = $false, ParameterSetName = '__bits')]
    [parameter(mandatory = $false, ParameterSetName = '__azcopy')]
    [switch]$HighPrio
)
$startTime = Get-Date
$bUseAzureStorageModule = $false
$OS = $OS.ToUpper()
$preFix = "REF" + $OS + "-"

#Determine PowerShell Version
if ($psVersionTable.PsVersion.Major -lt 5) {
    Write-Output  "Running on Powershell version $($PSVersionTable.PSVersion.ToString())"
    Write-Output  "Using the Azure.Storage module in this verion of PowerShell is not supported"
    if ($UseBitsDownload) {
        Write-Output  "Using BITS to download the image"
    }
    elseif ($UseAzCopy) {
        $azCopyInstall = @(Get-ItemProperty -Path HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Select-Object -Property DisplayName,InstallLocation | Where-Object {$_.DisplayName -match 'AzCopy'})[-1]
        if ($null -eq $azCopyInstall) {
            Throw "Unable to locate 'AzCopy.exe'. Please download and install AzCopy first before using the switch '-UseAzCopy'"
        }
        else {
            Write-Output  "Using AzCopy to download the files...."
        }
    }
    else {
        Write-Output  "Using BITS to download the image"
        $UseBitsDownload = $true
    }
    if ($CreateSasToken) {
        Write-Warning "Switch 'CreateSASToken' can only be used in conjunction with PowerShell 5, AzureRM.Profile module and AzureRM.Storage module"
        Write-Warning "Please use this switch on a computer with PowerShell 5 and the required AzureRM modules and then use the created SAS token (output) on this computer to download the image(s)"
        Throw
    }
}
else {
    if ($UseBitsDownload) {
        Write-Output  "Using BITS to download the files...."
    }
    elseif ($UseAzCopy) {
        $azCopyInstall = @(Get-ItemProperty -Path HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Select-Object -Property DisplayName,InstallLocation | Where-Object {$_.DisplayName -match 'AzCopy'})[-1]
        if ($null -eq $azCopyInstall) {
            Throw "Unable to locate 'AzCopy.exe'. Please download and install AzCopy first before using the switch '-UseAzCopy'"
        }
        else {
            Write-Output  "Using AzCopy to download the files...."
        }
    }
    else {
        try {
            Import-Module Azure.Storage -ErrorAction Stop
            $bUseAzureStorageModule = $true
        }
        catch {
            Write-Output  "AzureRM module could not be located/loaded on this computer"
            Write-Output  "Run the following command to download and install the latest version if you want to use AzureRM"
            Write-Output  "Find-Module -Name Azure.Storage | Install-Module"
            Write-Output  ""
            $azCopyInstall = @(Get-ItemProperty -Path HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object {$_.DisplayName -match 'AzCopy'})[-1]
            if ($null -eq $azCopyInstall) {
                Write-Output  "Using BITS to download the files......"
                $UseBitsDownload = $true    
            }
            else {
                Write-Output  "Using AzCopy to download the files....."
                $UseAzCopy = $true
            }
            $bUseAzureStorageModule = $false
        }        
    }
}

if ($sasToken -eq "") {
    #Login to Azure using the credentials from credentials
    try {
        Import-Module -Name AzureRM.Profile -ErrorAction Stop -WarningAction Stop
        if ($credential -eq ""){
            $credential = Get-Credential -Message "Please provide credential to connect to Azure and create a new SAS token for accessing storage account '$($storageAccountName)'"
        }
        Write-Output "Changing TLS settings to use TLS 1.2. This will fix an issue with logging on using Okta (Nike Default STS)"
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Write-Output "Connecting to Azure"
        Disable-AzureRmContextAutosave
        Connect-AzureRmAccount -Credential $credential
        $AzureSubscription = $null
        foreach ($subscription in (Get-AzureRmSubscription)) {
            Select-AzureRmSubscription $subscription  | out-null
            if (Get-AzureRmStorageAccount | Where-Object {$_.StorageAccountName -eq $StorageAccountName}) {
                Write-Output "Found storageaccount in subscription $($subscription.Name)"
                $AzureSubscription = $subscription
                break
            }
        }

        if ($AzureSubscription) {
            Select-AzureRmSubscription $AzureSubscription  | out-null
        }
        else {
            Throw "Unable to locate the correct subscription where storage account $($StorageAccountName) is located or the account does not have the right access for the storage account"
        }

    }
    catch {
        throw $_.Exception
    }

    try {
        $ResourceGroupName = (Get-AzureRmStorageAccount | Where-Object {$_.StorageAccountName -eq $StorageAccountName}).ResourceGroupName
        $StorageAccountKey = (Get-AzureRmStorageAccountKey -ResourceGroupName $resourceGroupName -Name $StorageAccountName)[1].Value
        $sasContext = New-AzureStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $StorageAccountKey
        $sasToken = New-AzureStorageAccountSASToken -Service Blob -ResourceType Container, Object, Service -Protocol HttpsOnly -StartTime (Get-Date) -ExpiryTime (Get-Date).AddHours(12.0) -Context $sasContext -Permission rl

        if ($CreateSasToken) {
            Write-Output ""
            Write-Output "The next SAS token is valid for 12 hours. Use the SAS token to download the image on a server that does not have PowerShell 5 installed"
            Write-Output "Example:"
            Write-Output "Get-NKReferenceImage -SasToken '$($sasToken)' -StorageAccountName 'p5filesstdsa01' -OS 'W2K12R2SE' -ImageType 'VHDX' -DestinationFolder 'D:\ReferenceImages'"
            Write-Output ""
            Write-Output "SAS Token: '$($sasToken)'"
            exit 0
        }
    }
    catch {
        throw $_.Exception 
    }
}


if ($bUseAzureStorageModule) {
    try {
        Write-Output  "Setting Azure Context to connect to the repository"
        $context = New-AzureStorageContext -StorageAccountName $storageAccountName -SasToken $sasToken
        Write-Output  "Testing connection to central repository"
        Get-AzureStorageBlob -Container $container -Context $context -MaxCount 2 -ErrorAction Stop | Out-Null
        Write-Output  "connected to central repository successfully"
    }
    catch {
        Throw
    }
}
    
$getBlob = @()
$blobImages = @()
$archivefolderName = '_ARCHIVE'
$blobImageFound = $false
if ($bUseAzureStorageModule) {
    $blobImages = Get-AzureStorageBlob -Container $container -Context $context -Prefix $prefix | Where-Object {$_.Name -notmatch $archivefolderName}
    $blobImages = $blobImages | Where-Object {$_.Name -match "$imageType"}
    if (($blobImages | Measure-Object).Count -ne 0) {
        $blobImageFound = $true
    }
}
else {
    $SASListToken = $SasToken.Replace("?", "&")
    $blobimages = Invoke-WebRequest -Uri "https://$StorageAccountName.blob.core.windows.net/$Container/?restype=container&comp=list&prefix=$($prefix)&maxresults=2000&include=metadata$($SASListToken)" -UseBasicParsing
    $blobimages = [xml]$blobimages.content.Substring(3)
    if (($blobimages.EnumerationResults.Blobs.Blob | Measure-Object).Count -ne 0) {
        $blobImageFound = $true
    }
}
if ($blobImageFound) {
    Switch ($imageType) {
        'OVF' {
            Write-Output  "Getting latest OVF files"
            if ($bUseAzureStorageModule) {
                $getBlob += @($($blobImages | Where-Object {($_.Name.EndsWith('.mf'))}))[-1]
                $getBlob += @($($blobImages | Where-Object {($_.Name.EndsWith('.ovf'))}))[-1]
                $getBlob += @($($blobImages | Where-Object {($_.Name.EndsWith('.vmdk'))}))[-1]
            }
            else {
                $getBlob += @($($blobimages.EnumerationResults.Blobs.Blob | where-object {$_.Name.Endswith('.mf')}))[-1]
                $getBlob += @($($blobimages.EnumerationResults.Blobs.Blob | where-object {$_.Name.Endswith('.ovf')}))[-1]
                $getBlob += @($($blobimages.EnumerationResults.Blobs.Blob | where-object {$_.Name.Endswith('.vmdk')}))[-1]
            }
        }
        'VHD' {
            Write-Output  "Getting latest VHD files"
            if ($bUseAzureStorageModule) {
                $getBlob += @($($blobImages | Where-Object {($_.Name.EndsWith('.vhd'))}))[-1]
            }
            else {
                $getBlob += @($($blobimages.EnumerationResults.Blobs.Blob | where-object {$_.Name.Endswith('.vhd')}))[-1]
            }
        }
        'VHDX' {
            Write-Output  "Getting latest VHDX files"
            if ($bUseAzureStorageModule) {
                $getBlob += @($($blobImages | Where-Object {($_.Name.EndsWith('.vhdx'))}))[-1]
            }
            else {
                $getBlob += @($($blobimages.EnumerationResults.Blobs.Blob | where-object {$_.Name.Endswith('.vhdx')}))[-1]
            }
        }
        'WIM' {
            Write-Output  "Getting latest WIM files"
            if ($bUseAzureStorageModule) {
                $getBlob += @($($blobImages | Where-Object {($_.Name.EndsWith('.wim'))}))[-1]
            }
            else {
                $getBlob += @($($blobimages.EnumerationResults.Blobs.Blob | where-object {$_.Name.Endswith('.wim')}))[-1]
            }
        }
    }

    if (!(Test-Path $DestinationFolder)) {
        Write-Output  "Creating destination folder"
        New-Item -Path $DestinationFolder -ItemType Directory -Force
        Write-Output  "Created destination folder successfully"
    }
    foreach ($blob in $getBlob) {
        #adding information in a psobject so that it can be used in the calling script
        if (!(Test-Path -Path (Join-Path -Path $DestinationFolder -ChildPath $blob.Name))) {
            Write-Output  "Downloading file $($blob.Name) to $($DestinationFolder)"
            if ($bUseAzureStorageModule) {
                if ($HighPrio) {
                    Get-AzureStorageBlobContent -blob $blob.Name -Container $container -Destination $DestinationFolder -Context $context    
                }
                else {
                    Get-AzureStorageBlobContent -blob $blob.Name -Container $container -Destination $DestinationFolder -Context $context -ConcurrentTaskCount 2
                }
                $ImageResult = 'success'
            }
            elseif ($UseBitsDownload) {
                try {
                    $arrFolder = $blob.Name.Split("/")
                    $newfolder = $DestinationFolder
                    For ($i = 0; $i -lt $($arrFolder.Count) - 1; $i++) {
                        $newFolder = Join-Path -Path $newFolder -ChildPath $($arrFolder[$i])
                        New-Item -Path $newfolder -ItemType Directory -Force
                    }
                }
                catch {
                    Throw $_.Exception.Message
                }
                try {
                    Import-Module BitsTransfer
                    Write-Output  "Downloading the image file $($blob.Name) using BITS Transfer"
                    if (($ASync) -and ($HighPrio)) {
                        $job = Start-BitsTransfer -Source "https://$StorageAccountName.blob.core.windows.net/$Container/$($Blob.Name)$($SASToken)" -Destination $(Join-Path -Path $DestinationFolder -ChildPath $($blob.Name)) -Asynchronous
                    }
                    elseif (($ASync) -and !($HighPrio)) {
                        $job = Start-BitsTransfer -Source "https://$StorageAccountName.blob.core.windows.net/$Container/$($Blob.Name)$($SASToken)" -Destination $(Join-Path -Path $DestinationFolder -ChildPath $($blob.Name)) -Priority Normal -Asynchronous
                    }
                    elseif ((!($ASync)) -and ($HighPrio)) {
                        Start-BitsTransfer -Source "https://$StorageAccountName.blob.core.windows.net/$Container/$($Blob.Name)$($SASToken)" -Destination $(Join-Path -Path $DestinationFolder -ChildPath $($blob.Name))
                    }
                    else {
                        Start-BitsTransfer -Source "https://$StorageAccountName.blob.core.windows.net/$Container/$($Blob.Name)$($SASToken)" -Destination $(Join-Path -Path $DestinationFolder -ChildPath $($blob.Name)) -Priority Normal   
                    }

                    if ($ASync) {
                        Start-Sleep -Seconds 2
                        Write-Output  ""
                        Write-Output  "Using asynchronous BITS Transfer"
                        Write-Output  "If you stop this script now the download will continue"
                        Write-Output  "You need to use Get-BitsTransfer and Complete-BitsTransfer to check the download and complete the file"
                        Write-Output  "Only use Complete-BitsTransfer when you are sure the file has been downloaded"
                        try {
                            While ( ($job.JobState.ToString() -eq 'Transferring') -or ($job.JobState.ToString() -eq 'Connecting') ) {
                                $totalBytes = $Job.BytesTotal
                                $receivedBytes = $Job.BytesTransferred
                                $percent = $receivedBytes / $totalBytes * 100
                                $receivedBytes /= 1kb
                                $totalBytes /= 1kb
                                Write-Progress -Activity "Downloading image asynchronously..." -Status ("{0} kbytes \ {1} kbytes" -f $receivedBytes, $totalBytes) -PercentComplete $percent
                            }
                            Start-Sleep -Seconds 2
                            if ($job.FilesTransferred -eq $job.FilesTotal) {
                                Complete-BitsTransfer -BitsJob $Job
                                Write-Output  "Downloaded file $($blob.Name) successfully"
                            }
                            else {
                                Write-Output  "Download ended with status: $($job.Jobstate.ToString())"
                                Write-Output  "Status description: $($Job.ErrorDescription)"
                                Write-Output  "The download will continue in most cases when the connection is restored" 
                                Write-Output  "Please use Bits commands to resume the download."
                                Write-Output  "Use 'Get-BitsTransfer | FL *' to monitor the download status (look for BytesTransferred and Bytestotal)"
                                Write-Output  "When the file has been downloaded use 'Get-BitsTransfer | Complete-BitsTransfer' to complete the download"
                            }
                        }
                        catch {
                            Write-Output  "Bitstransfer ended with error: $($Job.InternelErrorCode)"
                            Write-Output  "Status description: $($Job.ErrorDescription)"
                            Write-Output  "The download will continue in most cases when the connection is restored" 
                            Write-Output  "Please use Bits commands to resume the download."
                            Write-Output  "Use 'Get-BitsTransfer | FL *' to monitor the download status (look for BytesTransferred and Bytestotal)"
                            Write-Output  "When the file has been downloaded use 'Get-BitsTransfer | Complete-BitsTransfer' to complete the download"
                        }
                    }
                    $ImageResult = 'success'
                }
                catch {
                    Write-Output  "An error occurred while downloading the requested image. Error: $($_.Exception.Message)"
                    $ImageResult = 'fail'
                }
            }
            elseif ($UseAzCopy) {
                try {
                    $arrFolder = $blob.Name.Split("/")
                    $newfolder = $DestinationFolder
                    For ($i = 0; $i -lt $($arrFolder.Count) - 1; $i++) {
                        $newFolder = Join-Path -Path $newFolder -ChildPath $($arrFolder[$i])
                        New-Item -Path $newfolder -ItemType Directory -Force
                    }
                }
                catch {
                    Throw $_.Exception.Message
                }
                
                try {
                    $azureSDKPath = $azCopyInstall.InstallLocation
                    $azExeFile = Join-Path -Path $azureSDKPath -ChildPath 'AzCopy.exe'
                    if (Test-Path $azExeFile) {
                        Write-Output "Downloading sources from Azure Storage using AZCopy"
                        $azLogFile = Join-Path -Path $Destinationfolder -ChildPath 'AZCopy.log'
                        if ($sasToken.StartsWith('?sv=')) {
                            if ($HighPrio) {
                                $argument = "/source:https://$StorageAccountName.blob.core.windows.net/$Container/$($Blob.Name) /Dest:$(Join-Path -Path $DestinationFolder -ChildPath $($blob.Name)) /SourceSAS:$SASToken /XO /XN /Y /V:$azLogFile"
                            }
                            else {
                                $argument = "/source:https://$StorageAccountName.blob.core.windows.net/$Container/$($Blob.Name) /Dest:$(Join-Path -Path $DestinationFolder -ChildPath $($blob.Name)) /SourceSAS:$SASToken /XO /XN /Y /V:$azLogFile /NC:2"
                            }
                            $result = Start-Process -FilePath $azExeFile -ArgumentList $argument -Wait -PassThru
                        }
                        else {
                            #Will probably not be used, but when the user is supplying the Storage Account Key, this wil be the argument!
                            if ($HighPrio) {
                                $argument = "/source:https://$StorageAccountName.blob.core.windows.net/$Container/$($Blob.Name) /Dest:$(Join-Path -Path $DestinationFolder -ChildPath $($blob.Name)) /SourceKey:$SASToken /XO /XN /Y /V:$azLogFile"
                            }
                            else {
                                $argument = "/source:https://$StorageAccountName.blob.core.windows.net/$Container/$($Blob.Name) /Dest:$(Join-Path -Path $DestinationFolder -ChildPath $($blob.Name)) /SourceKey:$SASToken /XO /XN /Y /V:$azLogFile /NC:10"
                            }
                            $result = Start-Process -FilePath $azExeFile -ArgumentList $argument -Wait -PassThru
                        }
                        if ($result.ExitCode -eq 0) {
                            $ImageResult = 'success'
                            Write-Output "All sources have been downloaded"
                        }
                        else {
                            $ImageResult = 'fail'
                        }
                    }
                    else {
                        $ImageResult = 'fail'    
                        Throw "Unable to locate 'AzCopy.exe'. Please download and install AzCopy first before using the switch '-UseAzCopy'"
                    } 
                }
                catch {
                    Throw $_.Exception.Message
                }
            }
        }
        else {
            Write-Warning "Image '$($blob.Name)' has already been downloaded to folder $($DestinationFolder). Please delete the file if you want to download it again"
            $ImageResult = 'present'
        }
    }
}
else {
    Write-Warning "Unable to find the latest reference image for Operating System '$($prefix)' and image type '$($ImageType)'"
    Write-Warning "Please try another Operating System or another image type"
    $ImageResult = 'fail'
}
$Endtime = Get-Date
Write-Output  "The script took $(($Endtime - $StartTime).Hours):Hours $(($Endtime - $StartTime).Minutes):Minutes $(($Endtime - $StartTime).Seconds):Seconds to complete."
if ($ImageResult -eq 'fail') {
    $r = new-object pscustomobject -property  @{ImageName = ""; ImagePath = ""; ImageResult = $ImageResult}
}
else {
    $r = new-object pscustomobject -property  @{ImageName = $($blob.Name); ImagePath = $(Join-Path -Path $DestinationFolder -ChildPath $blob.Name); ImageResult = $ImageResult}
}
Return $r
