
#Definer gammelt og nytt UPN i riktig Array (pass på at rekkefølgen er lik.)

$OldUPN = @(
    "bruker@whatever.no"
    "bruker2@whatever.no"
)

$NewUPN = @(
    "bruker@whatever.de"
    "bruker2@whatever.de"
)

#Koble til Azure AD og Exchange Online

Connect-MsolService
Connect-ExchangeOnline

foreach ($user in $users) {
    Set-MsolUserPrincipalName -UserPrincipalName $OldUpn -NewUserPrincipalName $NewUpn -WhatIf
}

Start-Sleep -s 5

foreach ($user in $users) {
    Set-Mailbox -identity $NewUPN -WindowsEmailAddress $NewUPN -WhatIf
}

#Hvis overnente ikke fungerer kan du også bare kjøre det som en one-liner:

# Set-MsolUserPrincipalName -UserPrincipalName navn@domene.no -NewUserPrincipalName navn@domene.no

# Set-Mailbox -identity navn@domene.no -WindowsEmailAddress navn@domene.no