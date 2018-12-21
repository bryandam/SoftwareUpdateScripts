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
Decline updates for editions of Windows 10 your organization does not support.
.DESCRIPTION
Decline updates for editions of Windows 10 your organization does not support.  If the LatestVersionOnly is left to its default value of True then for each edition only the latest version will be retained and all others declined.
.NOTES
You must un-comment the $SupportedEditions variable and add the editions your organization supports.
The KnownEditions variable holds a list of known editions to _try_ and prevent the script from going rogue if MS decides to change the naming scheme.  If ... or when ... they do this will need to be updated.
Written By: Bryan Dam
Version 1.0: 10/28/17
Version 2.0: 06/29/18 Fixed issue with selecting multiple editions.
#>
#Un-comment and add elements to this array for editions you support.
#Note: You must escape any parenthesis with the forward slash.  Ex.: "Office 365 Client Update - Monthly Channel \(Targeted\) Version"
#$SupportedEditions = @("Office 365 Client Update - Monthly Channel Version","Office 365 Client Update - Semi-annual Channel Version")

#Set this to $True to decline all but the latest version of each editions or $False to ignore versions.
$LatestVersionOnly=$False

#If Microsoft decides to change their naming scheme you will need to update this variable to support the new scheme.
$KnownEditions=@("Office 365 Client Update - First Release for Deferred Channel","Office 365 Client Update - First Release for Current Channel","Office 365 Client Update - Current Channel","Office 365 Client Update - Deferred Channel", "Office 365 Client Update - Monthly Channel Version","Office 365 Client Update - Monthly Channel \(Targeted\) Version","Office 365 Client Update - Semi-annual Channel Version","Office 365 Client Update - Semi-annual Channel \(Targeted\) Version")
Function Invoke-SelectUpdatesPlugin{


    $DeclineUpdates = @{}
    If (!$SupportedEditions){Return $DeclineUpdates}    
    $maxVersions = @{}
    $Office365Updates = ($ActiveUpdates | Where{$_.ProductTitles.Contains('Office 365 Client')})    
    
    #Loop through the updates and editions and determine the highest version number per edition.
    If ($LatestVersionOnly){
        ForEach ($Update in $Office365Updates){
            ForEach ($KnownEdition in $KnownEditions){
                If($Update.Title -match $KnownEdition){
                    If ($Update.Title -match "Version (\d+)"){
                        If ($Matches[1] -gt $maxVersions[$KnownEdition]) {$maxVersions.Set_Item($KnownEdition,$Matches[1])}
                    }
                }
            }
        }
    }

    #Loop through the updates and decline the desired updates.
    ForEach ($Update in $Office365Updates){
         ForEach ($KnownEdition in $KnownEditions){

                #Verify that the update is a known edition.
                If($Update.Title -match $KnownEdition){
                                                        
                    #Determine if the update is a supported version and what known edition it is.
                    $FoundSupportedVersion = $False
                    $FoundEdition=""
                    ForEach($SupportedEdition in $SupportedEditions){
                        If($Update.Title -match $SupportedEdition){
                            $FoundSupportedVersion = $True
                            $FoundEdition = $KnownEdition
                        }
                    }

                    #Check for exclusions
                    If (Test-Exclusions $Update)
                    {
                        #Do Nothing

                    #If a supported version was found and we're only keeping the latest version.                  
                    } ElseIf ($FoundSupportedVersion -and $LatestVersionOnly){
                        #Decline updates that are not the latest version.
                        If ($Update.Title -notlike "*Version $($maxVersions[$KnownEdition])*"){
                            $DeclineUpdates.Set_Item($Update.Id.UpdateId,"Office 365 Updates: Version")
                        }
                    #If a supported version was not found then decline it.
                    } ElseIf (! $FoundSupportedVersion) {
                        $DeclineUpdates.Set_Item($Update.Id.UpdateId,"Office 365 Updates: Edition")
                    }                                        
                } #If a Known Edition                 
            } #ForEach Edition


        
    } #Office 365 Updates
    Return $DeclineUpdates
}
