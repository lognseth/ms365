<#
.DESCRIPTION
    Klargjøring av organisasjonsprofil (Branding)
    Forberede og klargjøre for Microsoft Advanced Threat Protection
    Forberede og klargjøre for Office 365 Message Encryption
    Beskyttelse mot identitetstyveri (DKIM/DMARC)
    Backup av alle data (e-post, onedrive, sharepoint)
    Multi Factor Authentication

    Set DMARC
    _dmarc.domain.com. -- TXT -- TTL 3600 -- "v=DMARC1; p=reject; sp=reject;


.NOTES
    Name:           SikkerForvaltning
    Version:        1.0
    Author:         Mikael Lognseth @ Innit Cloud Solutions AS
    Creation Date:  02.02.2021
    Purpose/Change: Initial development
#>

Connect-MsolService
Connect-ExchangeOnline

$ErrorActionPreference = "SilentlyContinue"

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

#-------------
# ATP POLICIES
#-------------

Write-Host("Setting ATP Policies") -ForegroundColor Cyan

$AcceptedDomains = Get-AcceptedDomain
$PrimaryDomain = $AcceptedDomains | where {$_.Default -eq $true}
$PrimaryDomain = $PrimaryDomain.DomainName

New-SafeAttachmentPolicy -Name "Default safe attachment policy" -Redirect $false -Action DynamicDelivery

New-AntiPhishPolicy -Name "Default AntiPhish Policy" -AdminDisplayName "Default AntiPhish Policy" -EnableMailboxIntelligenceProtection $true -MailboxIntelligenceProtectionAction Quarantine -EnableSimilarUsersSafetyTips $true -EnableSimilarDomainsSafetyTips $true -EnableUnusualCharactersSafetyTips $true

New-SafeAttachmentRule -Name "Default Safe attachment rule" -SafeAttachmentPolicy "Default safe attachment policy" -Enabled $true
New-SafeLinksPolicy -Name "Default safe links policy" -ScanUrls $true -TrackClicks $true -EnableForInternalSenders $true

#-------------
# OME POLICIES
#-------------

Write-Host("Setting OME Policies") -ForegroundColor Cyan

if (Get-OMEConfiguration) {
    Write-Host("OME is configured for current organization. `nChecking that everything is set up correctly......") -ForegroundColor Green
    
    $SenderAddress = Get-MsolUser -All | ? {$_.IsLicensed -eq $true} | select -Last 1
    $IRMCheck = Test-IRMConfiguration -Sender $SenderAddress.UserPrincipalName
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
    $SenderAddress = Get-MsolUser -All | ? {$_.IsLicensed -eq $true} | select -Last 1
    $IRMCheck = Test-IRMConfiguration -Sender $SenderAddress
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
    Write-Host("$MFAUsers user(s) have not enabled MFA") -ForegroundColor Red    
} else {
    Write-Host("All users have enabled MFA") -ForegroundColor Green
}

#-----------
# DKIM SETUP
#-----------

Write-Host("Setting DKIM Signing config") -ForegroundColor Cyan

$DomainsHash = @{}
$DkimDomains = Get-AcceptedDomain
$Count = 0

foreach ($domain in $DkimDomains) {
    $Key = $Count += 1 
    $DomainsHash += @{$Key = $Domain.DomainName}
    #$domain.DomainName | % {$Domains += $domain.DomainName}
    Write-Host $domain.DomainName
}

$DomainsString = $DomainsHash | Out-String

Write-Host("List of domains without DKIM: `n" + $DomainsString) 

$DomainSelection = Read-Host("Please select domain to enable DKIM for")
$DomainSelection = [convert]::ToInt32($DomainSelection)

$DkimDomain = $DomainsHash[$DomainSelection]

if ($Dkimdomain -match (Get-DkimSigningConfig | ? {$_.DomainName -match $DkimDomain})) {
    
} else {
    New-DkimSigningConfig -DomainName $DkimDomain -KeySize 2048 -Enabled $false
}

#New-DkimSigningConfig -DomainName $DkimDomain -KeySize 2048 -Enabled $false

$Selector1 = Get-DkimSigningConfig -Identity $DkimDomain | select Selector1CNAME
$Selector1 = $Selector1.Selector1CNAME
$Selector2 = Get-DkimSigningConfig -Identity $DkimDomain | select Selector2CNAME
$Selector2 = $Selector2.Selector1CNAME

Write-Host("See below for information on what CNAME records to add to domain: `n 

Domain:                 Type     TTL     Data
selector1._Domainkey -- CNAME -- 3600 -- $Selector1
selector2._Domainkey -- CNAME -- 3600 -- $Selector2
")

$SetDKIMForNewDomain = "Yes"
While($SetDKIMForNewDomain -eq "Yes") {
    $SetDKIMForNewDomain = Read-Host("Setup DKIM for another Domain? (Yes/No)") 
    if ($SetDKIMForNewDomain -eq "No") {
        break
    }
    else {
    Write-Host("List of domains without DKIM: `n" + $DomainsString)

    $DomainSelection = Read-Host("Please select domain to enable DKIM for")
    $DomainSelection = [convert]::ToInt32($DomainSelection)
    $DkimDomain = $DomainsHash[$DomainSelection]

    New-DkimSigningConfig -DomainName $DkimDomain -KeySize 2048 -Enabled $false -WhatIf

    $Selector1 = Get-DkimSigningConfig -Identity $DkimDomain | select Selector1CNAME
    $Selector2 = Get-DkimSigningConfig -Identity $DkimDomain | select Selector2CNAME
    $Selector2 = $Selector2.Selector1CNAME
    
    $Selector1 = $Selector1.Selector1CNAME
    Write-Host("See below for information on what CNAME records to add to domain: `n 

    Domain:                 Type     TTL     Data
    selector1_.Domainkey -- CNAME -- 3600 -- $Selector1
    selector2_.Domainkey -- CNAME -- 3600 -- $Selector2
    ")
    }
}

#-----------
# DMARC SETUP
#-----------

$DmarcLevel = Read-Host("Do you want the strict [1], or less strict [2] DMARC setup?")

if ($DmarcLevel -eq 2) {
    Write-Host('Set the following TXT record for the domain(s):

    Domain    Type   TTL     Data
    _dmarc -- TXT -- 3600 -- "v=DMARC1; p=quarantine; sp=quarantine; pct=100; rua=mailto:dmarc@drift.innit.no; ruf=mailto:dmarc@drift.innit.no; fo=1"
    ')
}
if ($DmarcLevel -eq 1) {
    Write-Host('Set the following TXT record for the domain(s):

    Domain    Type   TTL     Data
    _dmarc -- TXT -- 3600 -- "v=DMARC1; p=quarantine; sp=quarantine"
    ')
}