# Credentials
$myCred = Get-AutomationPSCredential -Name "Admin"

# Connect to MSonline
Connect-MsolService -Credential $myCred

$customers = Get-MsolPartnerContract -All
Write-Host "Found $($customers.Count) customers for $((Get-MsolCompanyInformation).displayname)." -ForegroundColor DarkGreen

$LicensedAdmins = foreach($customer in $customers) {
    Write-Host "Retrieving license info for $($customer.name)" -ForegroundColor Green
    $role = Get-MsolRole -RoleName "Company Administrator"
    Get-MsolRoleMember -RoleObjectId $role.ObjectId -TenantId $customer.TenantId | Where-Object {$_.islicensed -eq $true}
}

$LicensedTestAccounts = foreach($customer in $customers) {
    Write-Host "Retrieving license info for $($customer.name)" -ForegroundColor Green
    Get-MsolUser -TenantId $customer.TenantId | Where-Object {$_.islicensed -eq $true}
}

$LicensedInnitAdmins = $LicensedAdmins | Where-Object {($_.Emailaddress -like "admin*") -or ($_.Emailaddress -match "ga-innit") -or ($_.Emailaddress -like "*innit*") -or ($_.Emailaddress -like "*test*") -or ($_.Displayname -like "*test*")}

$LicensedInnitTestAccounts = $LicensedTestAccounts | Where-Object {($_.Emailaddress -like "*test*") -or ($_.Displayname -like "*test*") -or ($_.Emailaddress -match "test") -or ($_.Displayname -match "test")}

$TotalLicensedAccountsRaw = $LicensedInnitAdmins + $LicensedInnitTestAccounts
$TotalLicensedAccounts = $TotalLicensedAccountsRaw | Select-Object Displayname,EmailAddress,UserPrincipalName,IsLicensed

Write-Output ( $TotalLicensedAccounts | ConvertTo-Csv -NoTypeInformation)