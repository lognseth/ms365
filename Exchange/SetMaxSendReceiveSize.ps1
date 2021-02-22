if (Get-Module -ListAvailable -Name ExchangeOnlineManagement) {
        
} 
else {
    Install-Module -Name ExchangeOnlineManagement
}

Import-Module ExchangeOnlineManagement
Connect-ExchangeOnline

function Set-GlobalMaxSendReceive { 

    try {
        Foreach ($mbx in Get-ExoMailbox) {
            $User = $mbx.userprincipalname
            Set-Mailbox -Identity $User -MaxSendSize 150mb -MaxReceiveSize 150mb
            }
        }
    catch {
        $ErrorName = $Error[0].exception.GetType().fullname
        $ErrorDescription = $Error[0].exception.Message
        "Something went wrong processing the command... `r`n $ErrorName `r`n $ErrorDescription `r`n SCRIPT TERMINATED `r`n " | Out-file -filepath $ErrorLog -append
    }
}

Set-GlobalMaxSendReceive