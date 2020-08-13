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
#   Decline-ByConfigMgrCustomSeverityOfLow.ps1
#   A helper script function to identify Software Updates in ConfigMgr/SCCM with
#      a Custom Severity set to Low (2)
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

Function Invoke-SelectUpdatesPlugin {
    $PluginName = 'Decline-ByConfigMgrCustomSeverityOfLow'
    $CustomSeverityName = 'Low'
    $DeclineUpdates = @{}
    Add-TextToCMLog $LogFile "Discovering Updates in ConfigMgr" $PluginName 1
    $ConfigMgrUpdatesCustomSeverityLow = @(Get-CMSoftwareUpdate -Fast -IsExpired $false | Where-Object { $_.CustomSeverityName -eq $CustomSeverityName } | Select-Object CI_UniqueID).CI_UniqueID #-IsDeployed $false { $_.CustomSeverity -eq 2 }
    Add-TextToCMLog $LogFile "$($ConfigMgrUpdatesCustomSeverityLow.count) Updates discovered in ConfigMgr with a Custom Severity of [$CustomSeverityName]" $PluginName 1
    $UpdatesMatchingConfigMgr = $ActiveUpdates | Where-Object { $_.Id.UpdateId -in $ConfigMgrUpdatesCustomSeverityLow }
    Add-TextToCMLog $LogFile "$($UpdatesMatchingConfigMgr.count) Updates in WSUS match an Update in ConfigMgr with a Custom Severity of [$CustomSeverityName]" $PluginName 1
    #Loop through the updates and decline any that match the version.
    ForEach ($Update in $UpdatesMatchingConfigMgr) {
        $DeclineUpdates.Set_Item($Update.Id.UpdateId, "ConfigMgr Custom Severity of $CustomSeverityName")
    }
    Return $DeclineUpdates
}