$OldUPN = @(
    "bruker@whatever.no"
    "bruker2@whatever.no"
)

$NewUPN = @(
    "bruker@whatever.de"
    "bruker2@whatever.de"
)

Connect-MsolService
Connect-ExchangeOnline

foreach ($user in $users) {
    Set-MsolUserPrincipalName -UserPrincipalName $OldUpn -NewUserPrincipalName $NewUpn -WhatIf
}

foreach ($user in $users) {
    Set-Mailbox -identity $NewUPN -WindowsEmailAddress $NewUPN -WhatIf
}