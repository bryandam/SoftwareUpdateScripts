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
Enter your synopsis here.
.DESCRIPTION
Provide a more full description here.
.NOTES
Written By: 
Version 1.0: 10/28/17
Version 1.1: 08/31/18
#>

Function Invoke-SelectUpdatesPlugin{

    $DeclineUpdates = @{}
    
    $UpdatesIMightHate = ($ActiveUpdates | Where {$_.Title -ilike '%Du.Du hast.Du hast mich%'})
    
    #Loop through the updates.
    ForEach ($Update in $UpdatesIMightHate){

        #Verify that the updates aren't being excluded.
        If (!Test-Exclusions $Update){

            #Enter all your fun logic to add updates to the hashtable.
            #$DeclineUpdates.Set_Item($Update.Id.UpdateId,"Reason for Declining")
        }
    }

    Return $DeclineUpdates
}
