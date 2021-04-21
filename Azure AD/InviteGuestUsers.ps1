<#
.DESCRIPTION
    Imported CSV file requires Displayname and Email headers.

.NOTES


#>

$CsvPath = ""
$UsersToInvite = Import-Csv -Path $CsvPath -Encoding UTF8

foreach ($User in $UsersToInvite) {
    New-AzureADMSInvitation -InvitedUserDisplayName $User.DisplayName -InvitedUserEmailAddress $User.Email -InviteRedirectURL "https://myapps.microsoft.com" -SendInvitationMessage $true
}
