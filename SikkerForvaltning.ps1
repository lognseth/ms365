<#
.NOTES
    Klargjøring av organisasjonsprofil (Branding)
    Forberede og klargjøre for Microsoft Advanced Threat Protection
    Forberede og klargjøre for Office 365 Message Encryption
    Beskyttelse mot identitetstyveri (DKIM/DMARC)
    Backup av alle data (e-post, onedrive, sharepoint)
    Multi Factor Authentication
#>

#Set DMARC
# _dmarc.domain.com. -- TXT -- TTL 3600 -- "v=DMARC1; p=reject; sp=reject;

Connect-MsolService
Connect-ExchangeOnline

#Load functions
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

#Variables
$Users = Get-Mailbox


#-----------
# DKIM SETUP
#-----------

Write-Host("Setting DKIM Signing config") -ForegroundColor Cyan

foreach ($domain in $AcceptedDomains) {
    $domain = $domain.DomainName
    $domain = Get-DkimSigningConfig -Identity $domain | where {$_.Enabled -eq $false}
    $domain = $domain.Domain
    New-DkimSigningConfig -DomainName $domain -Enabled $true
}

#-------------
# ATP POLICIES
#-------------

Write-Host("Setting ATP Policies") -ForegroundColor Cyan

$AcceptedDomains = Get-AcceptedDomain
$PrimaryDomain = $AcceptedDomains | where {$_.Default -eq $true}
$PrimaryDomain = $PrimaryDomain.DomainName

New-SafeAttachmentPolicy -Name "Default safe attachment policy"

Set-AntiPhishPolicy -Identity "Office365 AntiPhish Default" -EnableOrganizationDomainsProtection $true -EnableMailboxIntelligenceProtection $true -MailboxIntelligenceProtectionAction Quarantine -EnableSimilarUsersSafetyTips $true -EnableSimilarDomainsSafetyTips $true -EnableUnusualCharactersSafetyTips $true -Enabled $true

New-SafeAttachmentRule -Name "Default Safe attachment rule" -SafeAttachmentPolicy "Default safe attachment policy" -Enabled $true
New-SafeLinksPolicy -Name "Default safe links policy" -ScanUrls $true -TrackClicks $true -EnableForInternalSenders $true

#-------------
# OME POLICIES
#-------------

Write-Host("Setting OME Policies") -ForegroundColor Cyan

if (Get-OMEConfiguration) {
    Write-Host("OME is configured for current organization. `nChecking that everything is set up correctly......") -ForegroundColor Green    
    $Sender = Read-Host("Enter UPN of user in organization: ")
    $IRMCheck = Test-IRMConfiguration -Sender $Sender
    $IRM = $IRMCheck.Results.ToString()
    $Result = "OVERALL RESULT: PASS"

    if ($IRM -match $Result){
        Write-Host("Office Message Encryption is already configured.") -ForegroundColor Green
    } 
    else{
        Write-Host("Encountered error while testing configuration `nAttempting to fix......") -ForegroundColor Yellow
        Set-OMEConfiguration 
    }
}
else {
    New-OMEConfiguration -Identity "OME Configuration" -OTPEnabled $true
    Start-Sleep -Seconds 15
    $Sender = Read-Host("Enter UPN of user in organization: ")
    $IRMCheck = Test-IRMConfiguration -Sender $Sender
    $IRM = $IRMCheck.Results.ToString()
    $Result = "OVERALL RESULT: PASS"

    if ($IRM -match $Result){
        Write-Host("Office Message Encryption is already configured.") -ForegroundColor Green
    } 
    else{
        Write-Host("Encountered error while testing configuration `nAttempting to fix......") -ForegroundColor Yellow
        Set-OMEConfiguration 
    }
}

#----------
# MFA Stuff
#----------

Write-Host("Getting MFA Status of all users") -ForegroundColor Cyan

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