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
Decline updates for defined versions of Windows 11.
.DESCRIPTION
Decline updates for defined versions of Windows 11.
.NOTES
You must un-comment the $UnsupportedVersions variable and add the versions your organization does not support.
Written By: Damien Solodow
Version 1.0: 01/15/2024
#>

#Un-comment and add elements to this array for versions you no longer support.
#$UnsupportedVersions = @("22H2")
Function Invoke-SelectUpdatesPlugin{

    $DeclineUpdates = @{}
    If (!$UnsupportedVersions){
        Return $DeclineUpdates
    }

    $Windows11Updates = ($ActiveUpdates | Where-Object{
            $_.ProductTitles.Contains('Windows 11')
        })

    #Loop through the updates and decline any that match the version.
    ForEach ($Update in $Windows11Updates){

        #If the title contains a version number.
        If (
            ($Update.Title -match 'Version \d\d\d\d') -or ($Update.Title -match 'Version \d\d[Hh][1-2]') -and
            (! (Test-Exclusions $Update))
        ){

            #Capture the version number.
            $Version = $matches[0].Substring($matches[0].Length - 4)

            #If the version number is in the list then decline it.
            If ($UnsupportedVersions.Contains($Version)){
                $DeclineUpdates.Set_Item($Update.Id.UpdateId, "Windows 11 Version: $($Version)")
            }
        }
    }
    Return $DeclineUpdates
}
