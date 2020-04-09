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
Written By: Damien Solodow @dsolodow
Version 1.0: 04/09/2020
#>

$3rdParties = @('Patch My PC', 'Lenovo')
Function Invoke-SelectUpdatesPlugin {

    $DeclineUpdates = @{}
    If (!($3rdParties)) {
        Return $DeclineUpdates
    }

    $SupersededUpdates = ($ActiveUpdates | Where-Object {$_.IsSuperseded -eq $true -and $_.UpdateClassificationTitle -ne 'Definition Updates' -and $_.CompanyTitles -ne 'Microsoft'})

    #Loop through the updates.
    ForEach ($Update in $SupersededUpdates) {
        foreach ($Vendor in $3rdParties) {
            If ($Update.CompanyTitles -match $Vendor) {
                #Verify that the updates aren't being excluded.
                If (!(Test-Exclusions $Update)) {

                    #Enter all your fun logic to add updates to the hashtable.
                    $DeclineUpdates.Set_Item($Update.Id.UpdateId, "3rd Party Updates: Superceded")
                }
            }
        }
    }

    Return $DeclineUpdates
}
