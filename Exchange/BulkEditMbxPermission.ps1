Connect-ExchangeOnline

#Variables:
$FinanceAccounts = @("Regnskap - Backe Bergen", "Regnskap - Backe Entreprenør", "Regnskap - Backe Norddvest", "Regnskap - Backe Rogaland", "Regnskap - Backe Romerike", "Regnskap - Backe Stor-Oslo", "Regnskap - Backe Vestfold Telemark", "Regnskap - Backe Østfold", "Regnskap - Martin M. Bakken", "Regnskap - Mjøsen Murmesterforretning")

foreach ($Account in $FinanceAccounts) {
    $Mailboxes = Get-mailbox -RecipientTypeDetails SharedMailbox | Where-Object {$_.DisplayName -match $Account}
    foreach ($Mailbox in $Mailboxes) {
        Add-MailboxPermission -Identity $Mailbox.Displayname -User "Trond Frogner" -AccessRights FullAccess
    }
}

#Sjekk at tilgangen har blitt satt

foreach ($Account in $FinanceAccounts) {
    $Mailboxes = Get-mailbox -RecipientTypeDetails SharedMailbox | Where-Object {$_.DisplayName -match $Account}
    foreach ($Mailbox in $Mailboxes) {
        Get-MailboxPermission -Identity $Mailbox.UserPrincipalName -User "Trond Frogner"
    }
}

