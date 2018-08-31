<#
.SYNOPSIS
Decline Windows 10 updates based on language. 
.DESCRIPTION
Decline Windows 10 updates for languages that are not selected to download software update files in the Software Update Point component. 
.NOTES
If you are using stand-alone WSUS be sure to modify the SupportedUpdateLanguages variable to hard code the languages you support.
Be sure to always include an 'all' element for language-independant updates.


Written By: Bryan Dam
Version 1.0: 10/25/17
Version 2.0: 04/16/18
    Add support for running against a stand-alone WSUS server.
Version 2.4: 07/20/18
    Added support for Win 7 and 8.1 in place upgrade updates.
#>


Function Invoke-SelectUpdatesPlugin{

    $DeclineUpdates = @{}
    
    #Determine how to create the supported update language array.
    If ($StandAloneWSUS){
        $SupportedUpdateLanguages=@("en","all")
    }
    Else{
        #Get the supported languages from the SUP component, exiting if it's not found, then add the 'all' language, and split them into an array.
        $SupportedUpdateLanguages=((Get-CMSoftwareUpdatePointComponent).Props).Where({$_.PropertyName -eq 'SupportedUpdateLanguages'}).Value2
        If (!$SupportedUpdateLanguages){Return $DeclineUpdates}
        $SupportedUpdateLanguages = ($SupportedUpdateLanguages.ToLower() + ",all").Split(',')
    }
    

    #Get the Windows 10 updates.
    $Windows10Updates = ($ActiveUpdates | Where{(($_.ProductTitles.Contains('Windows 10')) -or ($_.Title -ilike "Windows 7 and 8.1 upgrade to Windows 10*"))})
    
    #Loop through the updates and decline any that don't support the defined languages.
    ForEach ($Update in $Windows10Updates){
        
        #Loop through the updates's languages and determine if one of the defined languages is found.
        $LanguageFound = $False
        ForEach ($Language in $Update.GetSupportedUpdateLanguages()){
            If ($SupportedUpdateLanguages.Contains($Language)) {$LanguageFound=$True}
        }

        #If none of the defined languages were found then decline the update.
        If (! $LanguageFound -and (! (Test-Exlusions $Update))){            
            $DeclineUpdates.Set_Item($Update.Id.UpdateId,"Windows 10 Language: $($Update.GetSupportedUpdateLanguages())")
        }
    }
    Return $DeclineUpdates
}
