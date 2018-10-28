<#
.SYNOPSIS
Decline updates for defined versions of Windows 10 except for LTSB.
.DESCRIPTION
Decline updates for defined versions of Windows 10 except for LTSB.
.NOTES
You must un-comment the $UnsupportedVersions variable and add the versions your organization does not support.
Written By: Bryan Dam
Version 1.0: 7/31/18
#>

#Un-comment and add elements to this array for versions you no longer support.
$UnsupportedVersions = @("1507","1511", "1607")
Function Invoke-SelectUpdatesPlugin{

    $DeclineUpdates = @{}
    If (!$UnsupportedVersions){Return $DeclineUpdates}

    $Windows10Updates = ($ActiveUpdates | Where{((($_.ProductTitles.Contains('Windows 10')) -and (! $_.ProductTitles.Contains('Windows 10 LTSB'))) -or ($_.Title -ilike "Windows 7 and 8.1 upgrade to Windows 10*"))})
    
    #Loop through the updates and decline any that match the version.
    ForEach ($Update in $Windows10Updates){

        #If the title contains a version number.
        If ($Update.Title -match "Version \d\d\d\d" -and (! (Test-Exclusions $Update))){
            
            #Capture the version number.
            $Version = $matches[0].Substring($matches[0].Length - 4)
            
            #If the version number is in the list then decline it.
            If ($UnsupportedVersions.Contains($Version)){
                $DeclineUpdates.Set_Item($Update.Id.UpdateId,"Windows 10 Version: $($Version)")
            }
        }
    }
    Return $DeclineUpdates
}
