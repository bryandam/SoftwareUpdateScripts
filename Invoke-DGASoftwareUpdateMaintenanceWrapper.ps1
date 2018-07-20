################################################################################
#.SYNOPSIS
#   Invoke-DGASoftwareUpdateMaintenance_for_Site_XYZ.ps1
#   A wrapper script to call Invoke-DGASoftwareUpdateMaintenance.ps1 and prevent
#      command line parameters from being truncated in a Command Prompt such as when called by Windows Task Scheduler
#.EXAMPLE
#   Invoke-DGASoftwareUpdateMaintenanceWrapper.ps1
#   No parameters are supported by design except common parameters such as WhatIf
#.LINK
#   Reference Invoke-DGASoftwareUpdateMaintenance.ps1
#.NOTES
#   This script is maintained at https://github.com/???????????????????
#   Additional information about the function or script.
#   ========== Keywords ==========
#   Keywords: WSUS SUP SCCM ConfigMgr Decline Expire Update Maintenance Superseded
#   ========== Change Log History ==========
#   - 2018/04/30 by Chad.Simmons@CatapultSystems.com - Created
#   - 2018/04/30 by Chad@ChadsTech.net - Created
################################################################################
#region    ######################### Parameters and variable initialization ####
	[CmdletBinding(SupportsShouldProcess=$false)]
	Param (
	)
#endregion ######################### Parameters and variable initialization ####

$ScriptPath = 'S:\Scripts\Scheduled'
$SiteCode = 'FCA'
$LogFile = 'T:\Logs\DGASoftwareUpdateMaintenance\Invoke-DGASoftwareUpdateMaintenance.log'
$UpdateListOutputFile = 'T:\Logs\DGASoftwareUpdateMaintenance\UpdateList.csv'
$RollupForWindowsMaxRuntime = 60
$RollupForDotNETMaxRuntime = 120
$FeatureUpdateMaxRuntime = 360
$DeclineByTitle = @('*for ARM64-based Systems*','*Beta*','* Preview of *','Feature update to Windows 10 * en-gb','Feature update to Windows 10 (consumer editions)*') #,'Windows 7 and 8.1 upgrade to Windows 10 Pro, version 1*')
$CommonParams = @{'SiteCode'="$SiteCode"; 'UpdateListOutputFile'="$UpdateListOutputFile"; 'LogFile'="$LogFile"}
$MaxUpdateRuntime = @{'*Security Monthly Quality Rollup For Windows*'=$RollupForWindowsMaxRuntime;'*Security and Quality Rollup for .NET*'=$RollupForDotNETMaxRuntime;'Feature Update*'=$FeatureUpdateMaxRuntime}
Push-Location "$ScriptPath"

If ($WhatIf -or $WhatIfPreference) {
	.\Invoke-DGASoftwareUpdateMaintenance.ps1 @CommonParams -Force -DeclineByPlugins -DeclineByTitle $DeclineByTitle -WhatIf
} else {
	.\Invoke-DGASoftwareUpdateMaintenance.ps1 @CommonParams -Force -DeclineByPlugins -DeclineByTitle $DeclineByTitle -MaxUpdateRuntime $MaxUpdateRuntime -DeclineSuperseded -ExclusionPeriod 1 -RunCleanUpWizard -CleanSUGs -ReSyncUpdates
}
Pop-Location