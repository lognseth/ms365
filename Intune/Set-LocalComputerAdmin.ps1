<#
  .SYNOPSIS
    Setter bruker definert i $upn som Admin på PC
  .DESCRIPTION
    Setter bruker definert i $upn som Admin på PC
  .INPUTS

  .OUTPUTS

  .NOTES
    Name:           User_Disable-KeyboardLayoutSwitchShortcut
    Version:        1.0
    Author:         Ola Brustad @ Innit Drift AS
    Creation Date:  03.09.2020
    Purpose/Change: Initial script development

    Setter Language og Layout HotKey til none
    Å sette kun HotKey funerte ikke

    #1 Key Sequence enabled; use LEFT ALT+SHIFT to switch between locales.
    #2 Key Sequence enabled; use CTRL+SHIFT to switch between locales.
    #3 Key Sequences disabled.
  .EXAMPLE

#>

#Set $upn to user you are looking for
$upn = "Trinetornlund.johansen@backe.no"
function Convert-ObjectIdToSid
{
    param([String] $ObjectId)
    $d=[UInt32[]]::new(4);[Buffer]::BlockCopy([Guid]::Parse($ObjectId).ToByteArray(),0,$d,0,16);"S-1-12-1-$d".Replace(' ','-')
}
Connect-AzureAD

#Find User that needs to become local admin. Change searchstring as needed
$user = Get-AzureADUser -ObjectId $upn | select -Property ObjectId
$UserSid = Convert-ObjectIdToSid($user.ObjectId)
#Get Company admin and Device Admin
$CompAdminOid = Get-AzureADDirectoryRole | Where-Object {$_.displayName -like 'Company Administrator'} | Select -property ObjectId
$DevAdminOid = Get-AzureADDirectoryRole | Where-Object {$_.displayName -like 'Device Administrators'} | Select -property ObjectId
$CompAdminSid = Convert-ObjectIdToSid($CompAdminOid.ObjectId)
$DevAdminSid = Convert-ObjectIdToSid($DevAdminOid.ObjectId)
#Creates the XML
$xml = @"
<groupmembership>
	<accessgroup desc = "S-1-5-32-544">
		<member name = "Administrator" />
        <member name = "$CompAdminSid" />
        <member name = "$DevAdminSid" />
		<member name = "$UserSid" />
	</accessgroup>
</groupmembership>
"@

#Writes XML to screen
Write-Host "Copy this xml and paste into rule in Intune" -ForegroundColor Green
Write-Host
Write-Host $xml -ForegroundColor Yellow
