<#
.SYNOPSIS
Decline x86 updates for Windows products except for Windows Server 2008 (non-R2) and .NET
.DESCRIPTION
Decline x86 updates for Windows products except for Windows Server 2008 (non-R2) and .NET
.NOTES

Written By: Bryan Dam
Version 1.0: 07/27/18
#>


Function Invoke-SelectUpdatesPlugin{
    
    $DeclinedUpdates = @{}

    #Not declined, don't contain '.NET', contain 'x86', product includes 'Windows', product is not 'Windows Server 2008'
    $WindowsX86Updates = ($Updates | Where{!$_.IsDeclined -and ($_.Title -notlike '*.NET*') -and ($_.Title -ilike '*x86*') -and ($_.ProductTitles -ilike '*Windows*') -and ($_.ProductTitles -ne 'Windows Server 2008')})

    #Loop through the updates and decline any that match the version.
    ForEach ($Update in $WindowsX86Updates) {
        $DeclinedUpdates.Set_Item($Update.Id.UpdateId,"Windows X86 (32-bit)")
    }
    Return $DeclinedUpdates
}