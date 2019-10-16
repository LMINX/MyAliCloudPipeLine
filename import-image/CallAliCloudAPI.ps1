<#
2019/09/30 finally fixed the issue reagarding alicloud authencation code 
#>

$global:WebSession = $null
function Get-WebResponse {
    param(
        [Parameter(Position = 0, mandatory = $false)]
        $BaseUrl,
        [Parameter(Position = 1, mandatory = $false)]
        $SubUrl,
        $UserAgent = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/54.0.2840.71 Safari/537.36',
        [hashtable]$GetParameter,
        $AllowRedirect = $True,
        $session = $global:WebSession,
        $ContentType,
        $Body,
        $Method,
        $Timeout
    )
    $FullUrl = $Baseurl + $SubUrl
    $Request = [System.UriBuilder]($FullUrl)
    $HttpValueCollection = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
    if ($GetParameter -ne $null) {
        foreach ($item in $GetParameter.GetEnumerator()) {
            $HttpValueCollection.Add($Item.Key, $Item.Value)
        }
        $Request.Query = $HttpValueCollection.ToString()
        write $Request.Query
        write $Request.Uri
    }
    #write-host  $Request.Uri 
    if ($global:WebSession -ne $null) {
        if ($AllowRedirect) {
            if ($ContentType -ne $null -and $Body -ne $null -and $method -ne $null) {
                #  "Type 1"
                if ($Timeout -ne $null) {
                    $Response = Invoke-WebRequest -Uri $Request.Uri -UserAgent $UserAgent -WebSession $global:WebSession -ContentType $ContentType -Body $Body -Method $Method -TimeoutSec $Timeout
                }
                else {
                    $Response = Invoke-WebRequest -Uri $Request.Uri -UserAgent $UserAgent -WebSession $global:WebSession -ContentType $ContentType -Body $Body -Method $Method
                }
                
            }
            else {
                #  "Type 2"
                if ($Timeout -ne $null) {
                    $Response = Invoke-WebRequest -Uri $Request.Uri -UserAgent $UserAgent -WebSession $global:WebSession -TimeoutSec $Timeout
                }
                else {
                    $Response = Invoke-WebRequest -Uri $Request.Uri -UserAgent $UserAgent -WebSession $global:WebSession
                }
                
            }
            
        }
        else {
            if ($ContentType -ne $null -and $Body -ne $null -and $method -ne $null) {
                # "Type 3"
                if ($Timeout -ne $null) {
                    $Response = Invoke-WebRequest -Uri $Request.Uri -UserAgent $UserAgent -WebSession $global:WebSession -MaximumRedirection 0 -ContentType $ContentType -Body $Body -Method $Method -TimeoutSec $Timeout
                }
                else {
                    $Response = Invoke-WebRequest -Uri $Request.Uri -UserAgent $UserAgent -WebSession $global:WebSession -MaximumRedirection 0 -ContentType $ContentType -Body $Body -Method $Method
                }
                
            }
            else {
                #  "Type 4"
                "not allow redirect"
                if ($Timeout -ne $null) {
                    $Response = Invoke-WebRequest -Uri $Request.Uri -UserAgent $UserAgent -WebSession $global:WebSession  -MaximumRedirection 0  -TimeoutSec $Timeout #-SessionVariable 'session'
                }
                else {
                    $Response = Invoke-WebRequest -Uri $Request.Uri -UserAgent $UserAgent -WebSession $global:WebSession  -MaximumRedirection 0 #-SessionVariable 'session'
                }
                 
            }
        }

    }
    else {
        if ($AllowRedirect) {
            if ($ContentType -ne $null -and $Body -ne $null -and $method -ne $null) {
                #  "Type 5"
                if ($Timeout -ne $null) {
                    $Response = Invoke-WebRequest -Uri $Request.Uri -UserAgent $UserAgent -SessionVariable WebSession -ContentType $ContentType -Body $Body -method $Method -TimeoutSec $Timeout
                }
                else {
                    $Response = Invoke-WebRequest -Uri $Request.Uri -UserAgent $UserAgent -SessionVariable WebSession -ContentType $ContentType -Body $Body -method $Method
                }
                
            }
            else {
                #  "Type 6"
                if ($Timeout -ne $null) {
                    $Response = Invoke-WebRequest -Uri $Request.Uri -UserAgent $UserAgent  -SessionVariable WebSession -TimeoutSec $Timeout
                }
                else {
                    $Response = Invoke-WebRequest -Uri $Request.Uri -UserAgent $UserAgent  -SessionVariable WebSession             
                }

            }
            $global:WebSession = $WebSession
        }
        else {
            if ($ContentType -ne $null -and $Body -ne $null -and $method -ne $null) {
                #  "Type 7"
                if ($Timeout -ne $null) {
                    $Response = Invoke-WebRequest -Uri $Request.Uri -UserAgent $UserAgent -SessionVariable WebSession -MaximumRedirection 0 -ContentType $ContentType -Body $Body -method $Method -TimeoutSec $Timeout
                }
                else {
                    $Response = Invoke-WebRequest -Uri $Request.Uri -UserAgent $UserAgent -SessionVariable WebSession -MaximumRedirection 0 -ContentType $ContentType -Body $Body -method $Method                  
                }

            }
            else {
                #  "Type 8"
                "not allow redirect"
                if ($Timeout -ne $null) {
                    $Response = Invoke-WebRequest -Uri $Request.Uri -UserAgent $UserAgent  -SessionVariable WebSession -MaximumRedirection 0  -TimeoutSec $Timeout #-SessionVariable 'session' 
                }
                else {
                    $Response = Invoke-WebRequest -Uri $Request.Uri -UserAgent $UserAgent  -SessionVariable WebSession -MaximumRedirection 0 #-SessionVariable 'session'
                }
                
            }
            $global:WebSession = $WebSession
        }

    }

    return $Response
}


function Upper-UrlEsapeSting{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory='Ture')]
        [string]
        $QueryString
    )
    $reg=[regex]::new("%[a-f0-9]{2}")
    $matches=$reg.Matches($QueryString)
    foreach ($match in $matches)
    {
        $matchstring=$match.value
        $QueryString=$QueryString -replace ($matchstring, $matchstring.ToUpper())
    }
    $QueryString=$QueryString.replace("+", "%20").replace("*", "%2A").replace("%7E", "~")
    return $QueryString
}



$time=(Get-Date).ToUniversalTime().tostring('yyyy-MM-ddTHH:mm:ssZ')  
$r=New-Guid
$AccessKeyID='LTAI4FrLvwBAw4VrybhKEELr'
[Reflection.Assembly]::LoadWithPartialName("System.Web") | Out-Null
#$DisOrderGetParameter=@{'AccessKeyId'='LTAI4FrLvwBAw4VrybhKEELr';'Action'='Describeimages';'Format'='JSON';'PageSize'='10';'RegionId'='cn-hangzhou';'Version'='2014-05-26';'SignatureMethod'='HMAC-SHA1';'SignatureNonce'=$r;'SignatureVersion'='1.0';'TimeStamp'=$time}
#$DisOrderGetParameter=@{'AccessKeyId'='LTAI4FrLvwBAw4VrybhKEELr';'Action'='Describeimages';'Format'='JSON';'PageSize'='10';'RegionId'='cn-hangzhou';'Version'='2014-05-26';'SignatureMethod'='HMAC-SHA1';'SignatureNonce'='ffb3e080-e353-11e9-bb66-8c164511ab4d';'SignatureVersion'='1.0';'TimeStamp'='2019-09-30T07:29:12Z'}
$BucketName='vm-image-test'
$ImgName='win2016.vhd'
$KeyName='win2016.vhd'
$Arch='x86_64'
$Platform='Windows Server 2016'
$DisOrderGetParameter=@{'Action'='ImportImage';'RegionId'='cn-hangzhou';'DiskDeviceMapping.1.Format'='VHD';'DiskDeviceMapping.1.OSSBucket'=$BucketName;'DiskDeviceMapping.1.OSSObject'=$KeyName;'DiskDeviceMapping.1.DiskImageSize'='80';'ImageName'=$ImgName; `
'Description'='';'Architecture'=$Arch;Platform=$Platform; `
'AccessKeyId'='LTAI4FrLvwBAw4VrybhKEELr';'Format'='JSON';'PageSize'='10';'Version'='2014-05-26';'SignatureMethod'='HMAC-SHA1';'SignatureNonce'=$r;'SignatureVersion'='1.0';'TimeStamp'=$time}

$GetParameter=$DisOrderGetParameter.GetEnumerator()|Sort-Object -Property name
$BaseUrl = 'https://ecs.aliyuncs.com/'
$secret="Kzo721P1zNrn1vSdL2nyaqOCco1jsM&"
$HttpMethod='GET&%2F&'
$QueryString=''
$UpperUrlEscapeSubQueryString=$null
if ($GetParameter -ne $null) {
    foreach ($item in $GetParameter.GetEnumerator()) {
        $LowerUrlEscapeSubQueryString="&"+[System.Web.HttpUtility]::UrlEncode($item.key)+"="+[System.Web.HttpUtility]::UrlEncode($item.value)
        $UpperUrlEscapeSubQueryString+=Upper-UrlEsapeSting -Querystring $LowerUrlEscapeSubQueryString
    }       
}

$LowerUrlEscapeQueryString=$HttpMethod+[System.Web.HttpUtility]::UrlEncode($UpperUrlEscapeSubQueryString.Substring(1))
$UpperUrlEscapeQueryString=Upper-UrlEsapeSting -QueryString $LowerUrlEscapeQueryString
$UpperUrlEscapeQueryString

$sha = [System.Security.Cryptography.KeyedHashAlgorithm]::Create("HMACSHA1")
$sha.Key = [System.Text.Encoding]::UTF8.Getbytes($secret)
$singnature = [Convert]::Tobase64String($sha.ComputeHash([System.Text.Encoding]::UTF8.Getbytes(${UpperUrlEscapeQueryString})))
#$singnature


$DisOrderGetParameter.add('Signature',$singnature)
#$DisOrderGetParameter
$r=Get-WebResponse -BaseUrl $BaseUrl -GetParameter $DisOrderGetParameter

