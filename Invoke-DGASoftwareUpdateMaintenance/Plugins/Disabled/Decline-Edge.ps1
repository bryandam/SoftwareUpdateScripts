<#
.SYNOPSIS
Declines unsupported Channels, and older versions of Edge
.DESCRIPTION
Declines unsupported Channels, and optionally older and superceded versions of Edge
.NOTES
Written By: Damien Solodow @dsolodow
Version 1.0: 01/24/2020
#>
#Un-comment and add elements to this array for Channels you support.

#$SupportedChannels = @("Microsoft Edge-Stable Channel", "Microsoft Edge-Beta Channel", "Microsoft Edge-Dev Channel")

#Set this to $True to decline all but the latest version of each Channels or $False to ignore versions.
$LatestVersionOnly = $False

#If Microsoft decides to change their naming scheme you will need to update this variable to support the new scheme.
$KnownChannels = @("Microsoft Edge-Stable Channel", "Microsoft Edge-Beta Channel", "Microsoft Edge-Dev Channel")
Function Invoke-SelectUpdatesPlugin {


    $DeclineUpdates = @{}
    If (!$SupportedChannels) {
        Return $DeclineUpdates
    }
    $maxVersions = @{}
    $EdgeUpdates = ($ActiveUpdates | Where-Object {$_.ProductTitles.Contains('Microsoft Edge')})

    #Loop through the updates and Channels and determine the highest version number per Channel.
    If ($LatestVersionOnly) {
        ForEach ($Update in $EdgeUpdates) {
            ForEach ($KnownChannel in $KnownChannels) {
                If ($Update.Title -match $KnownChannel) {
                    If ($Update.Title -match "Version (\d+)") {
                        If ($Matches[1] -gt $maxVersions[$KnownChannel]) {
                            $maxVersions.Set_Item($KnownChannel, $Matches[1])
                        }
                    }
                }
            }
        }
    }

    #Loop through the updates and decline the desired updates.
    ForEach ($Update in $EdgeUpdates) {
        ForEach ($KnownChannel in $KnownChannels) {

            #Verify that the update is a known Channel.
            If ($Update.Title -match $KnownChannel) {

                #Determine if the update is a supported version and what known Channel it is.
                $FoundSupportedVersion = $False
                $FoundChannel = ""
                ForEach ($SupportedChannel in $SupportedChannels) {
                    If ($Update.Title -match $SupportedChannel) {
                        $FoundSupportedVersion = $True
                        $FoundChannel = $KnownChannel
                    }
                }

                #Check for exclusions
                If (Test-Exclusions $Update) {
                    #Do Nothing

                    #If a supported version was found and we're only keeping the latest version.
                } ElseIf ($FoundSupportedVersion -and $LatestVersionOnly) {
                    #Decline updates that are not the latest version.
                    If ($Update.Title -notlike "*Version $($maxVersions[$KnownChannel])*") {
                        $DeclineUpdates.Set_Item($Update.Id.UpdateId, "Edge Updates: Version")
                    }
                    If ($Update.IsSuperseded -eq "True") {
                        $DeclineUpdates.Set_Item($Update.Id.UpdateId, "Edge Updates: Version")
                    }
                    #If a supported version was not found then decline it.
                } ElseIf (! $FoundSupportedVersion) {
                    $DeclineUpdates.Set_Item($Update.Id.UpdateId, "Edge Updates: Channel")
                }
            } #If a Known Channel
        } #ForEach Channel



    } #Edge Updates
    Return $DeclineUpdates
}
