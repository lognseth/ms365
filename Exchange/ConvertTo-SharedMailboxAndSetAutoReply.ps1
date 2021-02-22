<#
.SYNOPSIS
    Converts selected mailboxes to shared mailbox and applies auto reply as defined below    

.DESCRIPTION
    Converts all selected users to shared mailbox, after this is done an automatic reply is applied on internal and external senders. 

.INPUTS
    N/A

.OUTPUTS
    N/A

.NOTES
    Version:        1.0
    Author:         Mikael Lognseth @ Innit Drift AS
    Creation Date:  27.05.2020
    Purpose/Change: Initial script development
  
.EXAMPLE
    Set-GlobalCalendarRights -User <USER GOES HERE> -AccessRights <ACCESS LEVEL GOES HERE>

#>


Connect-ExchangeOnline

$Mbx = "user1", "user2", "user3"

foreach ($M in $Mbx) {
Set-Mailbox -Identity $m -Type Shared
}

$AutoreplyStart = "03-Feb-2020 11:00"

$InternalMessage = "Intern melding"

$ExternalMessage = "Ekstern melding"

foreach ($M in $Mbx) {
# Set auto reply
    Write-Host "Setting auto-reply for shared mailbox:" $M
    Set-MailboxAutoReplyConfiguration -Identity $M -StartTime $Autoreplystart -AutoReplyState "Scheduled" -InternalMessage $InternalMessage –ExternalMessage  $ExternalMessage -ExternalAudience 'All' -CreateOOFEvent:$True 
}
