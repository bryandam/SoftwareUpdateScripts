<#
.SYNOPSIS
Enter your synopsis here.
.DESCRIPTION
Provide a more full description here.
.NOTES
Written By: 
Version 1.0: 10/28/17
Version 1.1: 08/31/18
#>

Function Invoke-SelectUpdatesPlugin{

    $DeclineUpdates = @{}
    
    $UpdatesIMightHate = ($ActiveUpdates | Where {$_.Title -ilike '%Du.Du hast.Du hast mich%'})
    
    #Loop through the updates.
    ForEach ($Update in $UpdatesIMightHate){

        #Verify that the updates aren't being excluded.
        If (!Test-Exclusions $Update){

            #Enter all your fun logic to add updates to the hashtable.
            #$DeclineUpdates.Set_Item($Update.Id.UpdateId,"Reason for Declining")
        }
    }

    Return $DeclineUpdates
}
