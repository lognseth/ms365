<#
    .SYNOPSIS
     Helsesjekk av Office 365 tenant
    .DESCRIPTION
     Kjører helsesjekk av ønsket tenant og gir deg output basert på følgende parametre:

     Identitetskontroll:
        Har brukere modern authentication
        Svake passord
        MFA

    Tilgangskontroll - kontoer:
        Ubrukte kontoer (ikke logget inn siste 60 dager)
        Oversikt over bruker-rettigheter på tenant
        Mistenkelige aktivitet
        
    Tilgangskontroll - geografi:
        Sjekk påloggingsforsøk
        Sjekk om pålogginger begrenses til område
    
    Begrenset Tilgangskontroll utenfor organisasjon:
        Deling med gjester
        Gjestebrukere
        Anonym deling

    .NOTES
     Name:              MS365-Helsesjekk.ps1
     Version:           1.0
     Author:            Mikael Lognseth @ Innit Drift AS
     Creation Date:     10.11.2020
     Purpose/Change:    Initial Script Development
#>

$ErrorActionPreference = "SilentlyContinue"

Function Get-AzureMFAStatus {

    [CmdletBinding()]
    param(
        [Parameter(
            Position=0,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true
            )]

        [string[]]   $UserPrincipalName,         
        [int]        $MaxResults = 4000,
        [bool]       $isLicensed = $true,
        [switch]     $SkipAdminCheck
    )
 
    BEGIN {
        if ($SkipAdminCheck.IsPresent) {
            $AdminUsers = Get-MsolRole -ErrorAction Stop | foreach {Get-MsolRoleMember -RoleObjectId $_.ObjectID} | Where-Object {$_.EmailAddress -ne $null} | Select EmailAddress -Unique | Sort-Object EmailAddress
        }
    }
 
    PROCESS {
        if ($UserPrincipalName) {
            foreach ($User in $UserPrincipalName) {
                try {
                    Get-MsolUser -UserPrincipalName $User -ErrorAction Stop | select DisplayName, UserPrincipalName, `
                        @{Name = 'isAdmin'; Expression = {if ($SkipAdminCheck) {Write-Output "-"} else {if ($AdminUsers -match $_.UserPrincipalName) {Write-Output $true} else {Write-Output $false}}}}, `
                        @{Name = 'MFAEnabled'; Expression={if ($_.StrongAuthenticationMethods) {Write-Output $true} else {Write-Output $false}}}
                              
                } catch {
                    $Object = [pscustomobject]@{
                        DisplayName       = '_NotSynced'
                        UserPrincipalName = $User
                        isAdmin           = '-'
                        MFAEnabled        = '-' 
                    }
                    Write-Output $Object
                }
            }
        } else {
            $AllUsers = Get-MsolUser -MaxResults $MaxResults | Where-Object {$_.IsLicensed -eq $isLicensed} | select DisplayName, UserPrincipalName, `
                @{Name = 'isAdmin'; Expression = {if ($SkipAdminCheck) {Write-Output "-"} else {if ($AdminUsers -match $_.UserPrincipalName) {Write-Output $true} else {Write-Output $false}}}}, `
                @{Name = 'MFAEnabled'; Expression={if ($_.StrongAuthenticationMethods) {Write-Output $true} else {Write-Output $false}}}
 
            Write-Output $AllUsers | Sort-Object isAdmin, MFAEnabled -Descending
        }
    }
    END {}
}

#Setter PSGallery til "trusted repo"
Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted

#Liste over relevante moduler

$Modules = @(
    "ExchangeOnlineManagement"
    "MSonline"
    "AzureADPreview"
    "Microsoft.Online.SharePoint.PowerShell"
    "Microsoft.Exchange.Management.ExoPowershellModule"
)

#sjekk om modulene er installert allerede, hvis nei installer dem.
foreach ($Module in $Modules) {
    if (!(Get-InstalledModule -Name $Module)) {
        Write-Host("$Module is not installed") -ForegroundColor Yellow
        Write-Host("Installing $Module") -ForegroundColor Green
		Install-Module -Name $Module -Confirm:$false -Force
		Import-Module -Name $Module
	}
	else {
		Write-Host("$Module is already installed.") -ForegroundColor Green
	}
}


$FolderPath = "C:\Innit\"
$OrganizationName = Read-Host("Organization name (The bit before .onmicrosoft): ")
$SPOurl = "https://" + $OrganizationName + "-admin.sharepoint.com"
$LogPath = Join-Path $FolderPath + "$OrganizationName.txt"

Start-Transcript -Path $LogPath -Force

#Autentisering:

Connect-ExchangeOnline
Connect-AzureAD
Connect-MsolService
Connect-SPOService -Url $SPOurl

#----------------------------
# EXCHANGE STUFF STARTS HERE
#----------------------------

$Users = Get-Mailbox -RecipientTypeDetails UserMailbox

$LicensedUsers = (Get-MsolUser | where {$_.IsLicensed -eq $true}).Count
Write-Host("Your organization currently has $LicensedUsers Licensed users") -ForegroundColor Cyan
$AuthPolicyUsers = 0
Write-Host("Getting authentication policies for all users") -ForegroundColor Cyan
foreach ($user in $users) {
    $AuthenticationPolicy = Get-AuthenticationPolicy -Identity $user.emailaddress
    if ($AuthenticationPolicy -ne $true) {
        Write-Host("No authentication policy found for $user") -ForegroundColor Yellow
        $AuthPolicyUsers++
    }
}

Write-Host("$AuthPolicyUsers users don't have an authentication policy") -ForegroundColor Red

Write-Host("Getting OAuthStatus")

$OAuthStatus = Get-OrganizationConfig | Select-Object OAuth2ClientProfileEnabled

if ($OAuthStatus -match $false) {
    Write-Host("Modern authentication is not enabled for organization") -ForegroundColor Red
}
if ($OAuthStatus -match $true) {
    Write-Host("Modern authentication is enabled for organization") -ForegroundColor Green
}

#Gets the date 60 days ago based on current time
$Users = Get-mailbox -RecipientTypeDetails UserMailbox
$60DaysBack = (Get-Date).AddDays(-60)
$ErrorActionPreference = "SilentlyContinue"
$UserLastSignInCount = 0

Write-Host("Checking if any users have been inactive for 60 days or more")

foreach ($User in $Users) {
	$LastUserAction = Get-mailboxstatistics -Identity $User.UserPrincipalName
	$LastUserAction = $LastUserAction.LastLogonTime
	$LastUserAction = $LastUserAction.ToString("dd/MM/yyyy HH:mm")
	if ($LastUserAction -ge $60DaysBack) {
        $LOT = (Get-mailboxstatistics -Identity $User.UserPrincipalName).LastLogonTime
        Write-Host("$User has not signed in over the past 60 days `nLast logon was: $LOT") -ForegroundColor Yellow
        $UserLastSignInCount++
	}
	else {
		Write-Host("$User has been signed in over the past 60 days") -ForegroundColor Green
	}
}

Write-Host("$UserLastSignInCount haven't been signed in over the past 60 days.")

Write-Host("Getting MFA Status of all users")

$MFAUsers = 0

foreach ($User in $Users) {
    $UserMFAStatus = Get-AzureMFAStatus -UserPrincipalName $User.UserPrincipalName
    if ($UserMFAStatus.MFAEnabled -eq $false) {
        Write-Host("$User has not enabled MFA") -ForegroundColor Yellow
        $MFAUsers++
    }
}

if ($MFAUsers -ne 0) {
    Write-Host("$MFAUsers user(s) haven't enabled MFA") -ForegroundColor Red    
} else {
    Write-Host("All users have enabled MFA") -ForegroundColor Green
}

#-----------------------------
# SHAREPOINT STUFF STARTS HERE
#-----------------------------

$Sites = Get-SPOSite

foreach ($Site in $Sites) {
    $SiteSharing = $Site.SharingCapability.ToString()
    $SiteTitle = $Site.Title
    $SiteUrl = $Site.Url
    if ($SiteSharing -eq "ExternalUserAndGuestSharing") {
        Write-Host("$SiteTitle is shared externally!`nSite URL: $SiteUrl")
    }
}

#---------------------------
# AZURE AD STUFF STARTS HERE
#---------------------------



Stop-Transcript