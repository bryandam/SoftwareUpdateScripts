################################################################################
#.SYNOPSIS
#   Decline-WindowsItanium.ps1
#   A helper script function to identify Windows Itanium, IA64 and AMD64 updates
#      for declining in WSUS and expiring in ConfigMgr/SCCM
#.LINK
#   Reference Invoke-DGASoftwareUpdateMaintenance.ps1
#.NOTES
#   This script is invoked by Invoke-DGASoftwareUpdateMaintenance.ps1 and not run independently
#
#   ========== Keywords ==========
#   Keywords: WSUS SUP SCCM ConfigMgr Decline Expire Update Maintenance Superseded
#   ========== Change Log History ==========
#   - 2018/04/30 by Chad.Simmons@CatapultSystems.com - Created
#   - 2018/04/30 by Chad@ChadsTech.net - Created
#   === To Do / Proposed Changes ===
#   - TODO: None
################################################################################

Function Invoke-SelectUpdatesPlugin{
    $DeclinedUpdates = @{}
    $WindowsItaniumUpdates = ($Updates | Where-Object {!$_.IsDeclined -and ($_.LegacyName -like '*-IA64-*' -or $_.ProductTitles -like '* Itanium*' -or $_.ProductTitles -like '* for IA64 *')})
    #Loop through the updates and decline any that match the version.
    ForEach ($Update in $WindowsItaniumUpdates) {
        $DeclinedUpdates.Set_Item($Update.Id.UpdateId,"Windows Itanium")
    }
    Return $DeclinedUpdates
}