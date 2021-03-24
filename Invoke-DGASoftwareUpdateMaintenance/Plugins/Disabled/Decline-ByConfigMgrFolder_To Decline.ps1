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

################################################################################
#.SYNOPSIS
#   Decline-ByConfigMgrFolder_To Decline.ps1
#   A helper script function to identify Software Updates in ConfigMgr/SCCM
#      moved to a folder named "To Decline"
#      for declining in WSUS and expiring in ConfigMgr/SCCM
#.LINK
#   Reference Invoke-DGASoftwareUpdateMaintenance.ps1
#.NOTES
#   This script is invoked by Invoke-DGASoftwareUpdateMaintenance.ps1 and not run independently
#
#   ========== Keywords ==========
#   Keywords: WSUS SUP SCCM ConfigMgr Decline Expire Update Maintenance Superseded
#   ========== Change Log History ==========
#   - 2020/08/13 by Chad.Simmons@CatapultSystems.com - Created
#   - 2020/08/13 by Chad@ChadsTech.net - Created
#   === To Do / Proposed Changes ===
#   - TODO: None
################################################################################

Function Invoke-SelectUpdatesPlugin{
    $PluginName = 'Decline-ByConfigMgrFolder'
    $FolderPath = 'To Decline'
    $DeclineUpdates = @{}
    Add-TextToCMLog $LogFile "Discovering Updates in ConfigMgr" $PluginName 1
    $ConfigMgrUpdatesInFolder = @(Get-CMSoftwareUpdate -Fast -IsExpired $false | Where-Object { $_.ObjectPath -eq "/$FolderPath" } | Select-Object CI_UniqueID).CI_UniqueID #-IsDeployed $false
    Add-TextToCMLog $LogFile "$($ConfigMgrUpdatesInFolder.count) Updates discovered in ConfigMgr in the folder [$FolderPath]" $PluginName 1
    $UpdatesMatchingConfigMgr = $ActiveUpdates | Where-Object { $_.Id.UpdateId -in $ConfigMgrUpdatesInFolder }
    Add-TextToCMLog $LogFile "$($UpdatesMatchingConfigMgr.count) Updates in WSUS match an Update in ConfigMgr in the folder [$FolderPath]" $PluginName 1
    #Loop through the updates and decline any that match the version.
    ForEach ($Update in $UpdatesMatchingConfigMgr) {
        $DeclineUpdates.Set_Item($Update.Id.UpdateId, "ConfigMgr Folder of [$FolderPath]")
    }
    Return $DeclineUpdates
}