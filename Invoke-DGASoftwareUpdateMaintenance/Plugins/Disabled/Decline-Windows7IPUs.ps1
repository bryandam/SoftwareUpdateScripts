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
