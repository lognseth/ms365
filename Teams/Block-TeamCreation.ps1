<#
    Only allows members of defined group to create Office 365 Groups, and by extension, Teams. This works well for organizations wishing to limit user control in Teams. 
    On the user side, the "Create Team" button will just be gone. 
    NB: Might impact ability to add tabs in channels for all users, workaround is to add users as members as well as owners on the groups belonging to the teams.
    Ref: https://docs.microsoft.com/en-us/microsoftteams/troubleshoot/known-issues/teams-owner-cannot-create-planner-tab
#>


$GroupName = Read-Host("Enter Displayname of Office 365 Group")
$AllowGroupCreation = "False"

Connect-AzureAD

$settingsObjectID = (Get-AzureADDirectorySetting | Where-object -Property Displayname -Value "Group.Unified" -EQ).id
if(!$settingsObjectID)
{
	$template = Get-AzureADDirectorySettingTemplate | Where-object {$_.displayname -eq "group.unified"}
    $settingsCopy = $template.CreateDirectorySetting()
    New-AzureADDirectorySetting -DirectorySetting $settingsCopy
    $settingsObjectID = (Get-AzureADDirectorySetting | Where-object -Property Displayname -Value "Group.Unified" -EQ).id
}

$settingsCopy = Get-AzureADDirectorySetting -Id $settingsObjectID
$settingsCopy["EnableGroupCreation"] = $AllowGroupCreation

if ($GroupName) {
	$settingsCopy["GroupCreationAllowedGroupId"] = (Get-AzureADGroup -SearchString $GroupName).objectid
} else {
    $settingsCopy["GroupCreationAllowedGroupId"] = $GroupName
}

Set-AzureADDirectorySetting -Id $settingsObjectID -DirectorySetting $settingsCopy

(Get-AzureADDirectorySetting -Id $settingsObjectID).Values