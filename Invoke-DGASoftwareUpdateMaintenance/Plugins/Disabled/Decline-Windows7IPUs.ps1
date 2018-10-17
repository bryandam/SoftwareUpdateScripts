<#
.SYNOPSIS
Decline updates for Windows 7 and 8.1 inplace upgrades to Windows 10.
.DESCRIPTION
Decline updates for Windows 7 and 8.1 inplace upgrades to Windows 10.
.NOTES
Written By: Bryan Dam
Version 1.0: 07/25/18
#>

Function Invoke-SelectUpdatesPlugin{
    $DeclineUpdates = @{}
    $WindowsIPUUpdates = ($ActiveUpdates | Where-Object {$_.Title -ilike "Windows 7 and 8.1 upgrade to Windows 10*"})
    #Loop through the updates and decline them all.
    ForEach ($Update in $WindowsIPUUpdates) {
        $DeclineUpdates.Set_Item($Update.Id.UpdateId,"Windows 7 IPU")
    }
    Return $DeclineUpdates
}
