<#
.SYNOPSIS
Determine if Device is in a given Intune filter.

.DESCRIPTION
Filters, how do they work?! 

.PARAMETER FilterId
The Filter ID to test.

.PARAMETER DeviceId
The AzureAD Device ID of the device you wish to search for.

.EXAMPLE
Test-AssignmentFilter -FilterId ebaf5497-27z6-4bfb-ac98-aafc2317e42m -DeviceId a0e35867-744b-472r-9a90-df9c7d249623

.NOTES
#>
function Test-AssignmentFilter {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilterId,

        [Parameter(Mandatory = $true)]
        [ValidateSet('include','exclude')]
        [string]$FilterType,

        [Parameter(Mandatory = $true)]
        [string]$DeviceId
    )

    $uri = "https://graph.microsoft.com/beta/deviceManagement/assignmentFilters/$FilterId"
    Write-Debug "Calling $uri"
    $filterResponse = Invoke-MgGraphRequest -Uri $uri

    $tempFile = New-TemporaryFile
    $evalUri = "https://graph.microsoft.com/beta/deviceManagement/evaluateAssignmentFilter"
    $evalBody = @{
        data = @{
            platform = $filterResponse.platform
            rule = $filterResponse.rule
            search = $DeviceId
        }
    }
    Invoke-MgGraphRequest -Uri $evalUri -Method POST -Body $evalBody -OutputFilePath $tempFile
    $data = Get-Content $tempFile | ConvertFrom-Json -Depth 100
    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
    
    Write-Verbose "Filter Id: $FilterId`tFilterType:$FilterType`tDeviceId:$DeviceId`tRecords Found:$($data.TotalRowCount)"

    #The result is based on the type of filter and if records were found or not.
    if ($FilterType -eq 'include'){
        return ($data.TotalRowCount -gt 0)
    }
    else{
        return ($data.TotalRowCount -eq 0)
    }
}

<#
.SYNOPSIS
Determine if Device is in a given Intune filter.

.DESCRIPTION
Filters, how do they work?! 

.PARAMETER FilterId
The Filter ID to test.

.PARAMETER DeviceId
The AzureAD Device ID of the device you wish to search for.

.EXAMPLE
Test-AssignmentFilter -FilterId ebaf5497-27z6-4bfb-ac98-aafc2317e42m -DeviceId a0e35867-744b-472r-9a90-df9c7d249623

.NOTES
#>
function Test-Assignment {
    param(
        [Parameter(Mandatory = $true)]
        $Assignments,
        [Parameter(Mandatory = $true)]
        [string]$DeviceId
    )

    #Determine if the device is excluded from the policy.
    $foundExclude = $false
    foreach ($assignment in $Assignments)
    {
        $target = $assignment.target
        if (($target.'@odata.type' -eq '#microsoft.graph.exclusionGroupAssignmentTarget') -and $aadDeviceGroups.ContainsKey($target.groupId)) {
            Write-Verbose "Processing exclude target $($target.groupId)"
            #If a filter was found, test to see if the device should be included in the policy.
            if ($null -ne $target.deviceAndAppManagementAssignmentFilterId){
                if (Test-AssignmentFilter -FilterId $target.deviceAndAppManagementAssignmentFilterId -FilterType $target.deviceAndAppManagementAssignmentFilterType -DeviceId $intuneDeviceId ){
                    Write-Verbose "$(DeviceId) matched the filter"
                    $foundExclude = $true
                    break;
                }
            }
            #If no filter was found.
            else{
                $foundExclude = $true
                break
            }            
        }
    }
    #If an exclude was found, the skip to the next record
    if ($foundExclude)
        {
            Write-Verbose "Excluding deviceId $($DeviceId) from assignment $($assignment.id)"
            return $false
        }
    

    #Determine if the device is included in the policy.
    $foundInPolicy = $false
    foreach ($assignment in $Assignments)
    {
        $target = $assignment.target
        if (($target.'@odata.type' -eq '#microsoft.graph.groupAssignmentTarget') -and $aadDeviceGroups.ContainsKey($target.groupId)) {
            Write-Verbose "Processing include target $($target.groupId)"
            #If a filter was found, test to see if the device should be included in the policy.
            if ($null -ne $target.deviceAndAppManagementAssignmentFilterId){
                if (Test-AssignmentFilter -FilterId $target.deviceAndAppManagementAssignmentFilterId -FilterType $target.deviceAndAppManagementAssignmentFilterType -DeviceId $intuneDeviceId ){
                    Write-Verbose "$($DeviceId) matched the filter"
                    $foundInPolicy = $true
                }
            }
            #If no filter was found.
            else{
                $foundInPolicy = $true
                break
            }
            
        } 
    }
    return $foundInPolicy
}


<#
.SYNOPSIS
Determine if Device is in a given WUfB Deployment Service Audience.

.DESCRIPTION
Each WUfb Deployment Service deployment has an audience which represents a group of devices the deployment is targetting. These groups are distinct from all other grouping concepts including AzureAD. There is no device-centric call within the WUfB DS to list what audiences a device is on. This function then, does some very brute and inefficient stuff to figure out if or if not a given device is in a given audience.

.PARAMETER AudienceId
The Audience ID of a given deployment.

.PARAMETER DeviceId
The AzureAD Device ID of the device you wish to test.

.EXAMPLE
Test-DeviceInAudience -AudienceId 5434e3fc-5d8d-484a-kc32-908687279415 -DeviceId a0e35867-744b-472r-9a90-df9c7d249623

.NOTES
This is all horrible ... so horrible ... but I know of no other way.
I am.
Sorry.
So.
So.
Sorry.
#>
function Test-DeviceInAudience {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AudienceId,

        [Parameter(Mandatory = $true)]
        [string]$DeviceId
    )

    # Check exclusion list
    $uri = "https://graph.microsoft.com/beta/admin/windows/updates/deploymentAudiences/$AudienceId/exclusions"
    $exclusionResponse = Invoke-MgGraphRequest -Uri $uri

    foreach ($exclusion in $exclusionResponse.value) {
        if ($exclusion.'@odata.type' -eq '#microsoft.graph.windowsUpdates.updatableAssetGroup') {
            $groupMembersUri = "https://graph.microsoft.com/beta/admin/windows/updates/updatableAssets/$($exclusion.id)/microsoft.graph.windowsUpdates.updatableAssetGroup/members"
            $groupMembersResponse = Invoke-MgGraphRequest -Uri $groupMembersUri

            foreach ($groupMember in $groupMembersResponse.value) {
                if (($groupMember.id -eq $DeviceId)) {
                    return $false
                }
            }
        }
        elseif ($exclusion.id -eq $DeviceId) {
            return $false
        }
    }

    # Check inclusion in the audience
    $uri = "https://graph.microsoft.com/beta/admin/windows/updates/deploymentAudiences/$AudienceId/members"
    $audienceMemberResponse = Invoke-MgGraphRequest -Uri $uri

    foreach ($audienceMember in $audienceMemberResponse.value) {
        if ($audienceMember.'@odata.type' -eq '#microsoft.graph.windowsUpdates.updatableAssetGroup') {
            $groupMembersUri = "https://graph.microsoft.com/beta/admin/windows/updates/updatableAssets/$($audienceMember.id)/microsoft.graph.windowsUpdates.updatableAssetGroup/members"
            $groupMembersResponse = Invoke-MgGraphRequest -Uri $groupMembersUri

            foreach ($groupMember in $groupMembersResponse.value) {
                if (($groupMember.id -eq $DeviceId)) {
                    return $true
                }
            }
        }
        elseif ($audienceMember.id -eq $DeviceId) {
            return $true;
        }
    }

    return $false
}


cls 
$ProgressPreference = 'SilentlyContinue'

# Install Microsoft.Graph PowerShell module if not already installed
if (-not (Get-Module -Name Microsoft.Graph -ListAvailable)) {
    Install-Module -Name Microsoft.Graph -Scope CurrentUser -Force -AllowClobber
}

# Import the Microsoft.Graph module
#Import-Module -Name Microsoft.Graph

# Connect to Graph is not already connected.
if(-not (Get-MgContext -ErrorAction SilentlyContinue))
{
    #Select-MgProfile -Name "beta"
    Connect-MgGraph -NoWelcome -Scopes "WindowsUpdates.ReadWrite.All","User.Read.All","Device.Read.All","Group.Read.All", "Organization.Read.All", "Directory.Read.All", "Organization.ReadWrite.All", "Directory.ReadWrite.All", "DeviceManagementManagedDevices.Read.All", "DeviceManagementConfiguration.Read.All"
}

# Prompt for computer name
$computerName = Read-Host -Prompt "Enter the name of the computer"

# Query Intune for device information
$aadDevice = Get-MgDevice -Filter "displayName eq '$computerName'"

if (!$aadDevice) {
    Write-Output "Device with name '$computerName' not found."
    exit    
}

Write-Output "Computer Name: $($aadDevice.displayName)"

$aadObjectId = $aadDevice.id
$aadDeviceId = $aadDevice.DeviceId
$osVersion = $aadDevice.operatingSystemVersion
Write-Output "Object ID: $aadObjectId"
Write-Output "Device ID: $aadDeviceId"

$uri = "https://graph.microsoft.com/beta/deviceManagement/manageddevices?filter=azureADDeviceId eq '$aadDeviceId'"
Write-Debug "Calling $uri"
$response = Invoke-MgGraphRequest -Uri $uri
$intuneDevice = $response.Value | Select-Object -First 1
$intuneDeviceId = $intuneDevice.Id
Write-Output "Intune ID: $intuneDeviceId"

# Get list of AAD groups the device is in
$aadDeviceGroups = @{}
$uri = "https://graph.microsoft.com/beta/devices/$aadObjectId/transitiveMemberOf"
Write-Debug "Calling $uri"
$response = Invoke-MgGraphRequest -Uri $uri
foreach ( $group in $response.value ){
        if (!$aadDeviceGroups.ContainsKey($group.id)){
            $aadDeviceGroups.Add($group.id,$group.displayName)
        }        
    }
$uri = "https://graph.microsoft.com/beta/devices/$aadObjectId/memberOf"
Write-Debug "Calling $uri"
$response = Invoke-MgGraphRequest -Uri $uri
foreach ( $group in $response.value ){
    if (!$aadDeviceGroups.ContainsKey($group.id)){
        $aadDeviceGroups.Add($group.id,$group.displayName)
    }
}
Write-Host "AAD Device Groups:"
if ($aadDeviceGroups.Count -eq 0)
    {Write-Host "`tNo device groups found."}
else{
    foreach ($aadGroup in $aadDeviceGroups.GetEnumerator())
        {Write-Host "`t$($aadGroup.Value) ($($aadGroup.Key))"}
}

#Get the Primary User for the device
$uri = "https://graph.microsoft.com/beta/deviceManagement/manageddevices('$intuneDeviceId')/users"
Write-Debug "Calling $uri"
$response = Invoke-MgGraphRequest -Uri $uri
$primaryUser = $response.value | Select-Object -First 1
$primaryUserId = $primaryUser.id
Write-Host "Primary User: $($primaryUser.displayName) ($primaryUserId)"

$aadUserGroups = @{}
$uri = "https://graph.microsoft.com/beta/users/$primaryUserId/memberOf"
Write-Debug "Calling $uri"
$response = Invoke-MgGraphRequest -Uri $uri
foreach ( $group in $response.value ){
        if (!$aadUserGroups.ContainsKey($group.id)){
            $aadUserGroups.Add($group.id,$group.displayName)
        }        
    }
Write-Host "AAD User Groups:"
if ($aadUserGroups.Count -eq 0)
    {Write-Host "`tNo user groups found."}
else{
    foreach ($aadGroup in $aadUserGroups.GetEnumerator())
        {Write-Host "`t$($aadGroup.Value) ($($aadGroup.Key))"}
}

#Confirm Tenant is Enrolled
if ((Get-MgSubscribedSKU | Where-Object { $_.ServicePlans.ServicePlanName -eq "WINDOWSUPDATEFORBUSINESS_DEPLOYMENTSERVICE" }).Count -gt 0)
    {Write-Output "`nTenant: Enrolled in Deployment Service "}
else    
    {Write-Output "`nTenant: Not enrolled in Deployment Service "}

#Confirm that Device is enrolled
$uri = "https://graph.microsoft.com/beta/admin/windows/updates/updatableAssets/$aadDeviceId"
Write-Debug "Calling $uri"
$response = Invoke-MgGraphRequest -Uri $uri -SkipHttpErrorCheck

if (($null -eq $response) -or ($response.error.code -eq 'NotFound'))
    {Write-Output "Device Id: Not enrolled in Deployment Service by Device Id. "}
else
    {
        Write-Output "Device: Enrolled in Deployment Service by Device Id."

        # List any enrollment errors.
        $enrollmentErrors = $response.errors | ForEach-Object { $_.reason }
        if ($enrollmentErrors.Count -eq 0) {
            Write-Output "`tNo enrollment errors."
        }    
        else {
            foreach ($enrollmentError in $enrollmentErrors){
                Write-Output "`tEnrollment error: $enrollmentError"
            }
        }

        # List the update categories the device is enrolled in
        $updateCategories = $response.enrollments | ForEach-Object { $_.updateCategory }
        if ($updateCategories.Count -eq 0) {
            Write-Output "`tNot enrolled in any update categories."
        }    
        else {
            foreach ($category in $updateCategories){
                Write-Output "`tEnrollment for: $category"
            }
        }
    }


#Get the latest update installed on device.
$uri = "https://graph.microsoft.com/beta/admin/windows/updates/catalog/entries?`$filter=microsoft.graph.windowsUpdates.qualityUpdateCatalogEntry/productRevisions/any(c:c/id eq '$osVersion')&`$expand=microsoft.graph.windowsUpdates.qualityUpdateCatalogEntry/productRevisions"
Write-Verbose "Calling $uri"
$response = Invoke-MgGraphRequest -Uri $uri

if ($null -eq $response){
    Write-Output "`nOperating System Version: $osVersion"
    Write-Output "`tFailed to find the installed patch."
}
else{
        # Get the OS version and latest update.
        foreach($productRevision in $response.value.productRevisions){
            if ($productRevision.id -eq $osVersion){
                $productName = $productRevision.product
                $productVersion = $productRevision.version
                break
            }
        }
        Write-Output "`nOperating System Version: $productName $productVersion ($osVersion)"
        Write-Output "Last Installed Update: $($response.value.catalogName)"
        Write-Output "`t`tUpdate Id: $($response.value.id)"
        Write-Output "`t`tRelease Date: $($response.value.releaseDateTime.ToString("dddd, MMMM dd, yyyy"))"
        Write-Output "`t`tClassification: $($response.value.qualityUpdateClassification)"
        Write-Output "`t`tType: $($response.value.qualityUpdateCadence)"

        #Get the latest update for the device
        $uri = "https://graph.microsoft.com/beta/admin/windows/updates/catalog/entries?`$filter=microsoft.graph.windowsUpdates.qualityUpdateCatalogEntry/qualityUpdateClassification eq 'Security' and microsoft.graph.windowsUpdates.qualityUpdateCatalogEntry/productRevisions/any(c:c/version eq '$($productVersion)' and c/product eq '$($productName)')&`$expand=microsoft.graph.windowsUpdates.qualityUpdateCatalogEntry/productRevisions&`$orderby=releaseDateTime desc&`$top=1"
        Write-Debug "Calling $uri"
        $response = Invoke-MgGraphRequest -Uri $uri
        if ($null -ne $response){
            Write-Output "Latest Security Update: $($response.value.catalogName)"
            Write-Output "`t`tUpdate Id: $($response.value.id)"
            Write-Output "`t`tRelease Date: $($response.value.releaseDateTime.ToString("dddd, MMMM dd, yyyy"))"
            Write-Output "`t`tClassification: $($response.value.qualityUpdateClassification)"
            Write-Output "`t`tType: $($response.value.qualityUpdateCadence)"
        }
    }



#Get the legacy WUfB Deployments. The DS is migrating to policies but currently (April 2024) it's only for drivers.
$wufbLegacyDeployments = @{}
$uri = "https://graph.microsoft.com/beta/admin/windows/updates/deployments"
Write-Debug "Calling $uri"
$response = Invoke-MgGraphRequest -Uri $uri
Write-Verbose "Found a total of $($response.value.count) WUfB DS policies"
foreach ( $wufbLegacyDeployment in $response.value ){
    
    #Skip old policies that are archived and not in effect
    if ($wufbLegacyDeployment.state.effectiveValue -eq 'archived')
        {continue}

    if (Test-DeviceInAudience -AudienceId $wufbLegacyDeployment.audience.id -DeviceId $aadDeviceId)
        {$wufbLegacyDeployments.Add($wufbLegacyDeployment.id, $wufbLegacyDeployment)    }
    
}
Write-Verbose "Found a filtered set of $($wufbLegacyDeployments.count) policies that apply to this device."

#Calculate the next Patch Tuesday
$baseDate = ( Get-Date -Day 12 ).Date
$patchTuesday = $baseDate.AddDays( 2 - [int]$baseDate.DayOfWeek )
If ( (Get-Date) -lt $patchTuesday )
{
    $baseDate = $baseDate.AddMonths( 1 )
    $patchTuesday = $baseDate.AddDays( 2 - [int]$baseDate.DayOfWeek )
}
Write-Debug "Patch Tuesday: $patchTuesday"

# Get the Intune Update Rings
$intuneUpdateRings = @{}
$uri = 'https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations?$filter=isof(%27microsoft.graph.windowsUpdateForBusinessConfiguration%27)&$expand=assignments'
Write-Debug "Calling $uri"
$response = Invoke-MgGraphRequest -Uri $uri
foreach ( $intuneUpdateRing in $response.value ){
    #Add the Intune Update Rings if the device is targeted    
    Write-Verbose "Testing Intune Update Ring $($intuneUpdateRing.displayName)($($intuneUpdateRing.id))"
    if (!$intuneUpdateRings.ContainsKey($intuneUpdateRing.Id) -and (Test-Assignment -Assignments $intuneUpdateRing.assignments -DeviceId $intuneDeviceId )){
        $intuneUpdateRings.Add($intuneUpdateRing.Id, $intuneUpdateRing)            
    }   
}

Write-Host "`nIntune Update Rings:"
if ($intuneUpdateRings.Count -eq 0)
    {Write-Host "`tNo Intune update rings found."}
else{
    foreach ($intuneUpdateRing in $intuneUpdateRings.GetEnumerator())
        {
            Write-Host "`t$($intuneUpdateRing.Value.displayName) ($($intuneUpdateRing.Key))"
            Write-Host "`t`tQuality Deferal: $($intuneUpdateRing.value.qualityUpdatesDeferralPeriodInDays) days ($($patchTuesday.AddDays($intuneUpdateRing.value.qualityUpdatesDeferralPeriodInDays).ToString("dddd MMMM dd, yyyy")))"
            Write-Host "`t`tQuality Deadline: $($intuneUpdateRing.value.deadlineForFeatureUpdatesInDays) days ($($patchTuesday.AddDays($intuneUpdateRing.value.qualityUpdatesDeferralPeriodInDays + $intuneUpdateRing.value.deadlineForQualityUpdatesInDays).ToString("dddd MMMM dd, yyyy")))"
            Write-Host "`t`tQuality Grace Period: $($intuneUpdateRing.value.deadlineGracePeriodInDays) days"
            if ($intuneUpdateRing.value.qualityUpdatesPaused -eq $true)
            {
                $dateTime = [datetime]::Parse($intuneUpdateRing.value.qualityUpdatesPauseExpiryDateTime)
                Write-Host "`t`t`tQuality Paused until: $($dateTime.ToString("dddd, MMMM dd, yyyy"))"
            }
            
            
            Write-Host "`t`tFeature Deferal: $($intuneUpdateRing.value.featureUpdatesDeferralPeriodInDays)"
            if ($intuneUpdateRing.value.featureUpdatesPaused -eq $true)
            {
                $dateTime = [datetime]::Parse($intuneUpdateRing.value.featureUpdatesPauseExpiryDateTime)
                Write-Host "`t`t`tFeature Paused until: $($dateTime.ToString("dddd, MMMM dd, yyyy"))"
            }
            Write-Host "`t`tDriver Excluded: $($intuneUpdateRing.value.driversExcluded)"
            Write-Host "`t`tAllow Win 11: $($intuneUpdateRing.value.allowWindows11Upgrade)"
        
        }
}

# Get the Intune Feature Update policies
$intuneFeatureUpdates = @{}
$uri = 'https://graph.microsoft.com/beta/deviceManagement/windowsFeatureUpdateProfiles?$expand=assignments'
Write-Debug "Calling $uri"
$response = Invoke-MgGraphRequest -Uri $uri
foreach ( $intuneFeatureUpdate in $response.value ){
       
    #Add the Intune Feature Update Policies if the device is targeted    
    Write-Verbose "Testing Feature Update Policy $($intuneFeatureUpdate.displayName)($($intuneFeatureUpdate.id))"
    if (!$intuneFeatureUpdates.ContainsKey($intuneFeatureUpdate.Id) -and (Test-Assignment -Assignments $intuneFeatureUpdate.assignments -DeviceId $intuneDeviceId)){
        $intuneFeatureUpdates.Add($intuneFeatureUpdate.Id, $intuneFeatureUpdate)            
    }   
}

Write-Host "`nIntune Feature Update Policies"
if ($intuneFeatureUpdates.Count -eq 0)
    {Write-Host "`tNo Intune feature update policies found."}
else{
    foreach ($intuneFeatureUpdate in $intuneFeatureUpdates.GetEnumerator())
        {
            Write-Host "`t$($intuneFeatureUpdate.Value.displayName) ($($intuneFeatureUpdate.Key))"
            Write-Host "`t`tFeature Update: $($intuneFeatureUpdate.value.featureUpdateVersion)"
            Write-Host "`t`tWin 10 Fallback: $($intuneFeatureUpdate.value.installLatestWindows10OnWindows11IneligibleDevice)"      
        }
}

# Get the Quality Expedite Policies
$intuneExpeditePolicies = @{}
$uri = 'https://graph.microsoft.com/beta/deviceManagement/windowsQualityUpdateProfiles?$expand=assignments'
Write-Debug "Calling $uri"
$response = Invoke-MgGraphRequest -Uri $uri
foreach ( $intuneExpeditePolicy in $response.value ){
          
    #Add the Intune Expedite policy if the device is targeted    
    Write-Verbose "Testing Feature Update Policy $($intuneExpeditePolicy.displayName)($($intuneExpeditePolicy.id))"
    if (!$intuneExpeditePolicies.ContainsKey($intuneExpeditePolicy.Id) -and (Test-Assignment -Assignments $intuneExpeditePolicy.assignments -DeviceId $intuneDeviceId )){
        $intuneExpeditePolicies.Add($intuneExpeditePolicy.Id, $intuneExpeditePolicy)            
    }     
}

Write-Host "`nIntune Expedite Policies"
if ($intuneExpeditePolicies.Count -eq 0)
    {Write-Host "`tNo Intune expedite policies found."}
else{
    foreach ($intuneExpeditePolicy in $intuneExpeditePolicies.GetEnumerator())
        {
            # Get the full policy details
            $uri = "https://graph.microsoft.com/beta/deviceManagement/windowsQualityUpdateProfiles/$($intuneExpeditePolicy.Key)"
            Write-Debug "Calling $uri"
            $response = Invoke-MgGraphRequest -Uri $uri

            Write-Host "`t$($response.displayName) ($($response.Id))"
            Write-Host "`t`tUpdate: $($response.deployableContentDisplayName)"
            Write-Host "`t`tReleased On: $(($response.expeditedUpdateSettings.qualityUpdateRelease).ToString("dddd, MMMM dd, yyyy"))"
            Write-Host "`t`tDeployed On: $(($response.createdDateTime).ToString("dddd, MMMM dd, yyyy"))"
            Write-Host "`t`tDays Until Forced Reboot: $($response.expeditedUpdateSettings.daysUntilForcedReboot)"              
        }
}

#Find Expediated Quality Updates
$expediteReadinessDeployment = $null
$wufbExpediteDeployments = @{}
foreach ($wufbLegacyDeployment in $wufbLegacyDeployments.GetEnumerator())
{    
    #Filter for Expedited deployments
    if ($wufbLegacyDeployment.Value.settings.expedite.isExpedited -eq $true)
    {       
        # Separate Expedite deployments from Epedite Readiness deployments.
        if ($wufbLegacyDeployment.Value.settings.expedite.isReadinessTest -eq $true)
        {
            if ($expediteReadinessDeployment){
                Write-Warning "This device has two Expedite Readiness policies '$($wufbLegacyDeployment.Value.id)' and '$($expediteReadinessDeployment.id)' which is weird."
            }
            $expediteReadinessDeployment = $wufbLegacyDeployment.Value
            continue
        }
        else{
            $wufbExpediteDeployments.Add($wufbLegacyDeployment.Key, $wufbLegacyDeployment.Value)
        }
    }    
}

Write-Host "WUfB DS Expedite Deployments"
if ($wufbExpediteDeployments.Count -eq 0)
    {Write-Host "`tNo WUfB expedite policies found."}
else{
    foreach ($wufbExpediteDeployment in $wufbExpediteDeployments.GetEnumerator())
        {
            
            Write-Host "`tDeployment $($wufbExpediteDeployment.Key)"
            if ($wufbExpediteDeployment.Value.content.'@odata.type' -eq '#microsoft.graph.windowsUpdates.catalogContent' -and $wufbExpediteDeployment.Value.content.catalogEntry.'@odata.type' -eq '#microsoft.graph.windowsUpdates.qualityUpdateCatalogEntry'){
                #The DS doesn't expedite individual updates so lookup the display name in Intune based on the DS release date.
                $uri = "https://graph.microsoft.com/beta/deviceManagement/windowsUpdateCatalogItems/microsoft.graph.windowsQualityUpdateCatalogItem?filter=releaseDateTime eq $($wufbExpediteDeployment.Value.content.catalogEntry.releaseDateTime.ToString("yyyy-MM-ddTHH:mm:ss.fffK"))"
                Write-Debug "Calling $uri"
                $response = Invoke-MgGraphRequest -Uri $uri

                if ($response.value.Count -eq 0){
                    Write-Host "`t`tUpdate: Unkonwn Quality Update"
                }
                else {
                    Write-Host "`t`tUpdate: $($response.value.displayName)"
                }
            }
            Write-Host "`t`tReleased On: $(($wufbExpediteDeployment.Value.content.catalogEntry.releaseDateTime).ToString("dddd, MMMM dd, yyyy"))"
            Write-Host "`t`tDeployed On: $(($wufbExpediteDeployment.Value.createdDateTime).ToString("dddd, MMMM dd, yyyy"))"
            Write-Host "`t`tDays Until Forced Reboot: $($wufbExpediteDeployment.Value.settings.userExperience.daysUntilForcedReboot) days"
        }
}

# Handle Expedite Readiness deployment
if (!$expediteReadinessDeployment){
    Write-Host "`tNo WUfB DS Expedite Readiness Deployment found."
}
else{
    Write-Host "`tWUfB DS Expedite Readiness Deployment found ($($expediteReadinessDeployment.id))."
}

# Get the Intune Driver Policies
$intuneDriverPolicies = @{}
$uri = 'https://graph.microsoft.com/beta/deviceManagement/windowsDriverUpdateProfiles?$expand=assignments'
Write-Debug "Calling $uri"
$response = Invoke-MgGraphRequest -Uri $uri
foreach ( $intuneDriverPolicy in $response.value ){
    
    $foundInPolicy = $false
    foreach ($target in $intuneDriverPolicy.assignments.target)
    {
        if (($target.'@odata.type' -eq '#microsoft.graph.exclusionGroupAssignmentTarget') -and $aadDeviceGroups.ContainsKey($target.groupId)) {
            $foundInPolicy = $false
            break
        }
        elseif (($target.'@odata.type' -eq '#microsoft.graph.groupAssignmentTarget') -and $aadDeviceGroups.ContainsKey($target.groupId)) {
            $foundInPolicy = $true
        }

        if ($foundInPolicy -and !$intuneDriverPolicies.ContainsKey($intuneDriverPolicy.Id)){
            $intuneDriverPolicies.Add($intuneDriverPolicy.Id, $intuneDriverPolicy)            
        }
        
    }    
}

Write-Host "`nIntune Driver Update Policies"
if ($intuneDriverPolicies.Count -eq 0)
    {Write-Host "`tNo WUfB driver update policies found."}
else{
    foreach ($intuneDriverPolicy in $intuneDriverPolicies.GetEnumerator())
        {
            Write-Host "`t$($intuneDriverPolicy.value.displayName) ($($intuneDriverPolicy.Key))"

            Write-Host "`t`tApproval: $($intuneDriverPolicy.value.approvalType)"
            if ($null -ne $intuneDriverPolicy.value.deploymentDeferralInDays){
                Write-Host "`t`tDeferral: $($intuneDriverPolicy.value.deploymentDeferralInDays) days"
            }
            
            #Get the driver inventory.
            $uri = "https://graph.microsoft.com/beta/deviceManagement/windowsDriverUpdateProfiles/$($intuneDriverPolicy.Key)/driverInventories"
            Write-Debug "Calling $uri"
            $response = Invoke-MgGraphRequest -Uri $uri

            if ($response.value.Count -eq 0){
                Write-Host "`t`tNo Drivers Found"
            }
            else{
                Write-Host "`t`tDeployed Drivers:"
                foreach ($driver in $response.value){                                        
                    if ($driver.approvalStatus -eq 'approved'){
                        Write-Host "`t`t`t$($driver.name) ($($driver.version)): $([datetime]::Parse($driver.deployDateTime).ToString("dddd, MMMM dd, yyyy"))"
                    }
                }
            }
        }
}

# Get the WUfb Deployment Service Driver Policies
Write-Host "WUfB DS Driver Deployments:"
$uri = 'https://graph.microsoft.com/beta/admin/windows/updates/updatePolicies'
Write-Debug "Calling $uri"
$response = Invoke-MgGraphRequest -Uri $uri
foreach ( $wufbDsDriverPolicy in $response.value ){
    
    Write-Verbose "Processing Policy $($wufbDsDriverPolicy.id)"

    if (!$wufbDsDriverPolicy.autoEnrollmentUpdateCategories.Contains("driver"))
        {
            Write-Warning "Policy does not contain a driver policy. API changes might have occurred; please contact author."
            continue
        }

    # Make sure device is not in exclusion list
    Write-Verbose "Processing Policy Audience Member Exclusion $($wufbDsDriverPolicy.audience.id)"
    $foundExclusion = $false
    $uri = "https://graph.microsoft.com/beta/admin//windows/updates/deploymentAudiences/$($wufbDsDriverPolicy.audience.id
    )/exclusions"
    $audienceMemberResponse = Invoke-MgGraphRequest -Uri $uri
    foreach ($audienceMember in $audienceMemberResponse.value){
        Write-Verbose "Processing Policy Audience Member Exclusion $($audienceMember.id)"
        if ($audienceMember.'@odata.type' -eq '#microsoft.graph.windowsUpdates.updatableAssetGroup'){
            Write-Verbose "Processing Policy Audience Member Exclusion Updatable Group $($audienceMember.id)"
            $uri = "https://graph.microsoft.com/beta/admin/windows/updates/updatableAssets/$($audienceMember.id)/microsoft.graph.windowsUpdates.updatableAssetGroup/members"
            Write-Debug "Calling $uri"
            $groupMemberResponse = Invoke-MgGraphRequest -Uri $uri
            foreach ($groupMember in $groupMemberResponse.value){
                if (($groupMember.id -eq $aadObjectId) -or ($groupMember.id -eq $aadDeviceId)) {
                    $foundExclusion = $true
                    break   
                }
            }
        }
        elseif (($audienceMember.id -eq $aadObjectId) -or ($audienceMember.id -eq $aadDeviceId)) {
            $foundExclusion = $true
            break
        }
    }
    #If an exclusion was found, skip this record
    if ($foundExclusion)    {
        continue
    }
    
    # See if device is in the deployment audience.
    Write-Verbose "Processing Policy Audience Member Inclusion $($wufbDsDriverPolicy.audience.id)"
    $foundInPolicy = $false
    $uri = "https://graph.microsoft.com/beta/admin//windows/updates/deploymentAudiences/$($wufbDsDriverPolicy.audience.id
    )/members"
    Write-Debug "Calling $uri"
    $audienceMemberResponse = Invoke-MgGraphRequest -Uri $uri
    foreach ($audienceMember in $audienceMemberResponse.value){
        Write-Verbose "Processing Policy Audience Member Inclusion $($audienceMember.id)"
        if ($audienceMember.'@odata.type' -eq '#microsoft.graph.windowsUpdates.updatableAssetGroup'){
            Write-Verbose "Processing Policy Audience Member  InclusionUpdatable Group $($audienceMember.id)"
            $uri = "https://graph.microsoft.com/beta/admin/windows/updates/updatableAssets/$($audienceMember.id)/microsoft.graph.windowsUpdates.updatableAssetGroup/members"            
            Write-Debug "Calling $uri"
            $groupMemberResponse = Invoke-MgGraphRequest -Uri $uri
            foreach ($groupMember in $groupMemberResponse.value){
                if (($groupMember.id -eq $aadObjectId) -or ($groupMember.id -eq $aadDeviceId)) {
                    $foundInPolicy = $true
                    break   
                }
            }
        }
        elseif (($audienceMember.id -eq $aadObjectId) -or ($audienceMember.id -eq $aadDeviceId)) {
            $foundInPolicy = $true
            break
        }
    }

    if ($foundInPolicy){
        Write-Host "`tPolicy $($wufbDsDriverPolicy.id)"
        $uri = "https://graph.microsoft.com/beta/admin/windows/updates/updatePolicies/$($wufbDsDriverPolicy.id)/complianceChanges"
        Write-Debug "Calling $uri"
        $driverDeploymentResponse = Invoke-MgGraphRequest -Uri $uri
        foreach ( $wufbDsDriverDeployment in $driverDeploymentResponse.value ){
            if ((!$wufbDsDriverDeployment.isRevoked) -and ( $wufbDsDriverDeployment.content.catalogEntry.'@odata.type') -eq '#microsoft.graph.windowsUpdates.driverUpdateCatalogEntry' ){
                Write-Host "`t`t`t$($wufbDsDriverDeployment.content.catalogentry.displayname) ($($wufbDsDriverDeployment.content.catalogentry.version)): $([datetime]::Parse($wufbDsDriverDeployment.deploymentSettings.schedule.startDateTime).ToString("dddd, MMMM dd, yyyy"))"
            }

        }
    }
    
}