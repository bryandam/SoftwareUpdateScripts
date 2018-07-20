<#
.SYNOPSIS
Decline updates for defined versions of Windows 10.
.DESCRIPTION
Decline updates for defined versions of Windows 10.
.NOTES
You must un-comment the $UnsupportedVersions variable and add the versions your organization does not support.
Written By: Bryan Dam
Version 1.0: 10/25/17
Version 2.4: 07/20/18
    Added support for Win 7 and 8.1 in place upgrade updates.
#>

#Un-comment and add elements to this array for versions you no longer support.
#$UnsupportedVersions = @("1511")
Function Invoke-SelectUpdatesPlugin{

    $DeclinedUpdates = @{}
    If (!$UnsupportedVersions){Return $DeclinedUpdates}

    $Windows10Updates = ($Updates | Where{(($_.ProductTitles -eq "Windows 10") -or ($_.Title -ilike "Windows 7 and 8.1 upgrade to Windows 10*"))  -and !$_.IsDeclined })
    
    #Loop through the updates and decline any that match the version.
    ForEach ($Update in $Windows10Updates){

        #If the title contains a version number.
        If ($Update.Title -match "Version \d\d\d\d" -and (! (Test-Exlusions $Update))){
            
            #Capture the version number.
            $Version = $matches[0].Substring($matches[0].Length - 4)
            
            #If the version number is in the list then decline it.
            If ($UnsupportedVersions.Contains($Version)){
                $DeclinedUpdates.Set_Item($Update.Id.UpdateId,"Windows 10 Version: $($Version)")
            }
        }
    }
    Return $DeclinedUpdates
}
