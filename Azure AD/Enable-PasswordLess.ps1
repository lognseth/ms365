######### Secrets #########
$ApplicationId = 'YourAPPID'
$ApplicationSecret = 'YourAppPassword' | Convertto-SecureString -AsPlainText -Force
$TenantID = 'YourTenantID'
$RefreshToken = 'Refreshtoken'
$UPN = "Valid-upn"
######### Secrets #########
$credential = New-Object System.Management.Automation.PSCredential($ApplicationId, $ApplicationSecret)

$aadGraphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes 'https://graph.windows.net/.default' -ServicePrincipal -Tenant $tenantID
$graphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes 'https://graph.microsoft.com/.default' -ServicePrincipal -Tenant $tenantID

Install-module AzureADPreview -AllowClobber
import-module AzureADPreview
Connect-AzureAD -AadAccessToken $aadGraphToken.AccessToken -AccountId $upn -MsAccessToken $graphToken.AccessToken -TenantId $tenantID | Out-Null
$tenants = Get-AzureAdContract -All:$true
Disconnect-AzureAD

foreach ($tenant in $tenants) {

    write-host "Working on client $($tenant.defaultdomainname)"
    try {
        $CustAadGraphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes "https://graph.windows.net/.default" -ServicePrincipal -Tenant $tenant.CustomerContextId
        $CustGraphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes "https://graph.microsoft.com/.default" -ServicePrincipal -Tenant $tenant.CustomerContextId
        Connect-AzureAD -AadAccessToken $CustAadGraphToken.AccessToken -AccountId $upn -MsAccessToken $CustGraphToken.AccessToken -TenantId $tenant.CustomerContextId | out-null
        $exists = Get-AzureADPolicy | Where-Object -Property type -eq AuthenticatorAppSignInPolicy
        if ($exists) { write-host  "Policy exists for $($tenant.DefaultDomainName)"; continue }
        New-AzureADPolicy -Type AuthenticatorAppSignInPolicy -Definition '{"AuthenticatorAppSignInPolicy":{"Enabled":true}}' -isOrganizationDefault $true -DisplayName 'PasswordlessSignin'
    }
    catch {
        Write-Warning "Could not log into tenant $($tenant.DefaultDomainName) or retrieve policy. Error: $($_.Exception.Message)"
    }

}