$ErrorActionPreference = "SilentlyContinue"

$users = Get-EXOMailbox | ? {$_.PrimarySMTPAddress -match "@innit.no"}

foreach ($user in $users) { 
    Write-Host -ForegroundColor green Setting permission for $($user.UserPrincipalName) 
    Set-MailboxFolderPermission -Identity $($user.UserPrincipalName + ":\Kalender") -User Standard -AccessRights LimitedDetails
    Set-MailboxFolderPermission -Identity $($user.UserPrincipalName + ":\Calendar") -User Standard -AccessRights LimitedDetails
}

