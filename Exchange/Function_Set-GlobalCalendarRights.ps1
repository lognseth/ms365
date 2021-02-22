<#
.SYNOPSIS
    Module to simplify applying Calendar rights to all users.
    You need to be connected to Exchange Online Powershell for this script to function. This can be done like so:
    Install-Module ExchangeOnlineManagement
    Connect-ExchangeOnline (You will be prompted for credentials)

.DESCRIPTION
    Simple script that allows you to set calendar permissions for all users in an organization regardless of Office language. Wrapped in a try/catch for error handling.

.PARAMETER $User
    This is where you define the user that will be given access rights to all calendars in the organization, use "Default" as user if you want everyone access everything.

.PARAMETER $AccessRights
    This is where the AccessRights are defined. You can choose between these levels (Put a star on the commonly used ones):

    Owner — gives full control of the mailbox folder: read, create, modify and delete all items and folders. Also this role allows to manage items permissions;
    Editor — read, create, modify and delete items (can’t create subfolders);
    *Reviewer — read folder items only;
    *AvailabilityOnly — read Free/Busy info from the calendar;
    *LimitedDetails — Can see subject and location;
    None — no permissions to access folder and files.   


.INPUTS
    AccessRights and User, described above.

.OUTPUTS
    Verbose

.NOTES
    Version:        1.0
    Author:         Mikael Lognseth @ Innit Drift AS
    Creation Date:  26.05.2020
    Purpose/Change: Initial script development
  
.EXAMPLE
    Set-GlobalCalendarRights -User <USER GOES HERE> -AccessRights <ACCESS LEVEL GOES HERE>

#>

if (Get-Module -ListAvailable -Name ExchangeOnlineManagement) {
        
} 
else {
    Install-Module -Name ExchangeOnlineManagement
}

Import-Module ExchangeOnlineManagement
Connect-ExchangeOnline

function Set-GlobalCalendarRights { 
    
[CmdletBinding()]
param(
    [parameter(Mandatory=$true)]
    [string] $User, 
    
    [parameter(Mandatory=$true)]
    [string] $AccessRights
    )

    try {
        Foreach ($mbx in Get-ExoMailbox){
        $calendar=$mbx.alias+":\Calendar"
        Add-mailboxfolderpermission -identity $calendar -User $User -AccessRights $AccessRights
            }
    }

    catch {
        $ErrorName = $Error[0].exception.GetType().fullname
        $ErrorDescription = $Error[0].exception.Message
        "Something went wrong processing the command... `r`n $ErrorName `r`n $ErrorDescription `r`n SCRIPT TERMINATED `r`n " | Out-file -filepath $ErrorLog -append
    }
}

Set-GlobalCalendarRights