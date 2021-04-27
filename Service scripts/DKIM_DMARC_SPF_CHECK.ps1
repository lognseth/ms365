<#
######### Secrets #########
$ApplicationId = 'ApplicaitonId'
$ApplicationSecret = 'ApplicationSecret' | ConvertTo-SecureString -Force -AsPlainText
$TenantID = 'TenantID'
$RefreshToken = 'VeryLongRefreshToken'
######### Secrets #########
$credential = New-Object System.Management.Automation.PSCredential($ApplicationId, $ApplicationSecret)
 
$aadGraphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes 'https://graph.windows.net/.default' -ServicePrincipal -Tenant $tenantID
$graphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes 'https://graph.microsoft.com/.default' -ServicePrincipal -Tenant $tenantID
#>
Connect-MsolService #-AdGraphAccessToken $aadGraphToken.AccessToken -MsGraphAccessToken $graphToken.AccessToken

$domains = Get-MsolPartnerContract -All | Get-MsolDomain | where-object -Property IsInitial -eq $false
$Results = foreach ($Domain in $Domains) {
 
    $Selector1 = Resolve-DnsName -name "selector1._domainkey.$($Domain.name)" -Type CNAME -ErrorAction SilentlyContinue
    $selector2 = Resolve-DnsName -name "selector2._domainkey.$($Domain.name)" -Type CNAME -ErrorAction SilentlyContinue
    $DMARC = Resolve-DnsName -name "_dmarc.$($Domain.Name)" -Type TXT -ErrorAction SilentlyContinue
    $SPF = Resolve-DnsName -name "$($Domain.name)" -Type TXT -ErrorAction SilentlyContinue | Where-Object { $_.strings -like 'v=spf1*' }
 
    [PSCustomObject]@{
        'Domain'                     = $domain.Name
        "DKIM Selector 1 Configured" = [bool]$selector1
        "DKIM Selector 2 Configured" = [bool]$selector2
        'DMARC configured'           = [bool]$DMARC
        'SPF Configured'             = [bool]$SPF
        'DMARC Value'                = $DMARc.Strings
        'SPF Value'                  = $spf.strings
    }
}
 
$results | format-table