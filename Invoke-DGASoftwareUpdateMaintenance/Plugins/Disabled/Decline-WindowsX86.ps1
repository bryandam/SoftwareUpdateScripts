################################################################################
#.SYNOPSIS
#   Decline-WindowsX86.ps1
#   A helper script function to identify Windows 32-bit updates
#      for declining in WSUS and expiring in ConfigMgr/SCCM
#.LINK
#   Reference Invoke-DGASoftwareUpdateMaintenance.ps1
#.NOTES
#   This script is invoked by Invoke-DGASoftwareUpdateMaintenance.ps1 and not run independently
#
#   ========== Keywords ==========
#   Keywords: WSUS SUP SCCM ConfigMgr Decline Expire Update Maintenance Superseded
#   ========== Change Log History ==========
#   - 2018/07/27 by Chad.Simmons@CatapultSystems.com - Changed Decline Reason to include matching ProductTitle
#   - 2018/07/11 by Chad.Simmons@CatapultSystems.com - Added functionality for supported 32-bit operating systems so unsupported ones are declined
#   - 2018/04/30 by Chad.Simmons@CatapultSystems.com - Created
#   - 2018/04/30 by Chad@ChadsTech.net - Created
#   === To Do / Proposed Changes ===
#   - TODO: None
################################################################################

$SupportedWinX86Versions = @('Windows Server 2003, Datacenter Edition', 'Windows Server 2003', 'Windows Server 2008', 'Windows XP', 'Windows 7')
#KnownWinX86Versions = @('Windows Server 2003, Datacenter Edition','Windows Server 2003','Windows Server 2008','Windows XP','Windows 7','Windows 8','Windows 8.1','Windows 10')

Function Invoke-SelectUpdatesPlugin {
	[CmdletBinding()]
	$DeclinedUpdates = @{}
	$WindowsX86Updates = ($Updates | Where {!$_.IsDeclined -and ($_.LegacyName -notlike '*DOTNET*-X86-TSL') -and ($_.LegacyName -like 'WSUS*_x86' -or $_.LegacyName -like '*WINDOWS*-KB*-X86-*' -or $_.LegacyName -like 'KB*-*-X86-TSL')})
	#WINDOWS7CLIENT-KB982799-X86-308159-23798
	#WINDOWS7EMBEDDED-KB2124261-X86-325274-25932
	#KB4099989-Windows10Rs3Client-RTM-ServicingStackUpdate-X86-TSL-World
	#KB947821-Win7-SP1-X86-TSL
	#WINDOWS6-1-KB975891-X86-294176
	Add-TextToCMLog $LogFile "   Supported Windows X86 Products: $($SupportedWinX86Versions -join '; ')." $component 1

	#Loop through the updates and decline any that match the version.
	ForEach ($update in $WindowsX86Updates) {
		If (($update.ProductTitles | Select-String -pattern $SupportedWinX86Versions -SimpleMatch -List).Count -eq 0) {
			$DeclinedUpdates.Set_Item($Update.Id.UpdateId, "Unsupported OS: $($update.ProductTitles) (32-bit)")
		}
	}
	Write-Debug -Message 'Explore $Updates, $DeclinedUpdates, $WindowsX86Updates and $SupportedWinX86Versions'
	Return $DeclinedUpdates
}