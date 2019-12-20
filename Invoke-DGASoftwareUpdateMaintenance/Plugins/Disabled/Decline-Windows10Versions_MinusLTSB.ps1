<#
This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
#>

<#
.SYNOPSIS
Decline updates for defined versions of Windows 10 except for LTSB.
.DESCRIPTION
Decline updates for defined versions of Windows 10 except for LTSB.
.NOTES
You must un-comment the $UnsupportedVersions variable and add the versions your organization does not support.
Written By: Bryan Dam
Version 1.0: 7/31/18
Version 2.4.6: 12/20/19
    Add 1903+ and Insider product categories.

#>

#Un-comment and add elements to this array for versions you no longer support.
#$UnsupportedVersions = @("1507","1511", "1607")
Function Invoke-SelectUpdatesPlugin{

    $DeclineUpdates = @{}
    If (!$UnsupportedVersions){Return $DeclineUpdates}

    $Windows10Updates = ($ActiveUpdates | Where{((($_.ProductTitles.Contains('Windows 10') -or $_.ProductTitles.Contains('Windows 10, version 1903 and later') -or $_.ProductTitles.Contains('Windows Insider Pre-Release')) -and (! $_.ProductTitles.Contains('Windows 10 LTSB'))) -or ($_.Title -ilike "Windows 7 and 8.1 upgrade to Windows 10*"))})
    
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
