Connect-ExchangeOnline

$groups = Get-UnifiedGroup -ResultSize Unlimited
#Evt om de er i csv fil
#$groups = Import-Csv -Path .\BP_UnifiedGroups.csv -Delimiter "," -Encoding UTF8
$groups | ForEach-Object {
    Write-Host "Endrer:" $_.Name -ForegroundColor Green
    Set-UnifiedGroup -Identity $_.ExternalDirectoryObjectId -HiddenFromExchangeClientsEnabled:$true -HiddenFromAddressListsEnabled $true
}

$groups | Where-Object { $_.DisplayName -notlike "*alle*"} | Set-UnifiedGroup -HiddenFromExchangeClientsEnabled:$true -HiddenFromAddressListsEnabled:$true