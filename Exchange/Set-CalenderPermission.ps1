$ErrorActionPreference = "SilentlyContinue"

$users = Get-EXOMailbox | ? {$_.PrimarySMTPAddress -match "@something.no"} | Get-MailboxFolderStatistics | ? {$_.FolderType -eq "Calendar"} | select @{n="Identity"; e={$_.Identity.Replace("\",":\")}}

foreach ($user in $users) { 
    Write-Host -ForegroundColor green Setting permission for $($user.UserPrincipalName) 
    Set-MailboxFolderPermission -Identity $($user.UserPrincipalName + ":\Kalender") -User Standard -AccessRights LimitedDetails
    Set-MailboxFolderPermission -Identity $($user.UserPrincipalName + ":\Calendar") -User Standard -AccessRights LimitedDetails
}

