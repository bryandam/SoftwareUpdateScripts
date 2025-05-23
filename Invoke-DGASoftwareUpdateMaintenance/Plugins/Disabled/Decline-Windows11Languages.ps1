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
Decline Windows 11 updates based on language.
.DESCRIPTION
Decline Windows 11 updates for languages that are not selected to download software update files in the Software Update Point component.
.NOTES
If you are using stand-alone WSUS be sure to modify the SupportedUpdateLanguages variable to hard code the languages you support.
Be sure to always include an 'all' element for language-independant updates.


Written By: Damien Solodow
Version 1.0: 01/15/2024
#>


Function Invoke-SelectUpdatesPlugin{

    $DeclineUpdates = @{}

    #Determine how to create the supported update language array.
    If ($StandAloneWSUS){
        $SupportedUpdateLanguages = @('en', 'all')
    } Else{
        #Get the supported languages from the SUP component, exiting if it's not found, then add the 'all' language, and split them into an array.
        $SupportedUpdateLanguages = ((Get-CMSoftwareUpdatePointComponent).Props).Where({$_.PropertyName -eq 'SupportedUpdateLanguages'}).Value2
        If (!$SupportedUpdateLanguages){
            Return $DeclineUpdates
        }
        $SupportedUpdateLanguages = ($SupportedUpdateLanguages.ToLower() + ',all').Split(',')
    }


    #Get the Windows 11 updates.
    $Windows11Updates = $ActiveUpdates | Where-Object{($_.ProductTitles.Contains('Windows 11'))}

    #Loop through the updates and decline any that don't support the defined languages.
    ForEach ($Update in $Windows11Updates){

        #Loop through the updates's languages and determine if one of the defined languages is found.
        $LanguageFound = $False
        ForEach ($Language in $Update.GetSupportedUpdateLanguages()){
            If ($SupportedUpdateLanguages.Contains($Language)) {
                $LanguageFound = $True
            }
        }

        #If none of the defined languages were found then decline the update.
        If (! $LanguageFound -and (! (Test-Exclusions $Update))){
            $DeclineUpdates.Set_Item($Update.Id.UpdateId, "Windows 11 Language: $($Update.GetSupportedUpdateLanguages())")
        }
    }
    Return $DeclineUpdates
}
