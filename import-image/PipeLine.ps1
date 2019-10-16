<#
2019/09/24 GeorgeLiu: This function Get-WinImageFromAzure it used to downlaod the image from Aure Storage Account to local 
2019/09/26 GeorgeLiu: Use TF to upload the image to Alicloud OSS.
2019/09/30 GeorgeLiu: CallAliCloudAIP  to call the Alicloud API ,example import-image
2019/10/07 GeorgeLiu: intergreate with Jekins.

#>

function Get-WinImageFromAzure
{
  [CmdletBinding()]
  param (
      #[CmdletBinding]
      [Parameter(Mandatory=$False)]
      [String]
      $SAUsername=($env:USERDOMAIN+"\"+$env:USERNAME),
      [Parameter(Mandatory=$False)]
      [String]
      $SAPwd
  )

  if ($username -notmatch "NIKE\SA.")
  {
  $SAUserName=$SAUsername.replace("\","\SA.")
  }
  if($SAPwd -eq ""){
    $SACredential=Get-Credential -UserName $SAUserName -Message "Please input your SA account Password"
  } 
  else{
    $SecSaPwd=ConvertTo-SecureString $SAPwd -AsPlainText -Force
    $SACredential=New-Object System.Management.Automation.PSCredential($SAUsername,$SecSaPwd)
  }
  
  
  # validation the username and pwd
  #download the image form Azure need try catch 
  try{
    C:\GitRepo\MyAliCloudPipeLine\import-image\Get-NKReferenceImage.ps1 -Credential $SACredential -OS "W2K16SE" -ImageType "VHD" -DestinationFolder "C:\ReferenceImages"
  }
  catch 
  {

    throw $_.exception
  }
 



}

Get-WinImageFromAzure -SAUsername sa.gliu10@nike.com -SAPwd Docker!QAZ@WSX#EDC123 