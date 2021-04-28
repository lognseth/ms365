<#
.DESCRIPTION
    Imported CSV file requires Displayname and Email headers.
.NOTES
    Name:           InviteGuestUsers
    Version:        1.0
    Author:         Mikael Lognseth @ Innit Cloud Solutions AS
    Creation Date:  28.04.2021
    Purpose/Change: Initial development

#>

Connect-AzureAD

$CsvPath = ""
$UsersToInvite = Import-Csv -Path $CsvPath -Encoding UTF8

foreach ($User in $UsersToInvite) {
    New-AzureADMSInvitation -InvitedUserDisplayName $User.DisplayName -InvitedUserEmailAddress $User.SignInName -InviteRedirectURL "https://myapps.microsoft.com" -SendInvitationMessage $true
}
