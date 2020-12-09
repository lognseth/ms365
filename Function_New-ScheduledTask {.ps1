function New-ScheduledTask {
    param (
        [Parameter(Mandatory=$true)]
        [string]$taskName
    )
    #Create scheduled Task

    #Check if task already is created. Delete and recreate
    Get-ScheduledTask | Where-Object { ($_.'TaskName' -like $taskName) } | Unregister-ScheduledTask -Confirm:$false

    #User to run the scheduled task
    $user=$env:USERDOMAIN +"\"+$env:USERNAME;
    
    #Endre til azuread\upn
    Write-Output -InputObject ("USER: {0} " -f ($user));
    
    #Create Task    
    $scriptWithpath = $scriptPath + $scriptName;

    $principal= New-ScheduledTaskPrincipal -UserId 'NT AUTHORITY\SYSTEM' -RunLevel 'Highest'; `

    $action = New-ScheduledTaskAction -Execute $powershellPath -Argument ('-ExecutionPolicy Bypass -NoLogo -NonInteractive -NoProfile -WindowStyle Hidden -File "{0}"' -f ($scriptWithpath)) 


    $trigger = New-ScheduledTaskTrigger -Daily -At 9am
    Register-ScheduledTask -Action $action -Trigger $trigger -TaskName $taskName -Description $taskDescription -Principal $principal;


    # Check if task was created
    $taskExists = Get-ScheduledTask | Where-Object { $_.TaskName -like $taskName }

    if (!$taskExists) {
        Write-Output -InputObject ("Task was not created {0} " -f ($taskName));
        throw "Scehduled task not created";
    } 
}