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

.DESCRIPTION

.EXAMPLE
 powershell -executionpolicy bypass -file  .\Export-OSDSUS.ps1 -OutPutFile "test.xml" -Title "x86" -Products "Windows 10,Windows 7"

.NOTES


.LINK
http://www.damgoodadmin.com

#>

[CmdletBinding(SupportsShouldProcess=$True,DefaultParameterSetName="configfile")]
Param(
    #Array of strings to search for and decline updates that match.  Use wildcard operator (*) to match more than one update.    
    [string] $Title,

    
    #Array of product strings that will be included and declined.  This inclusion will apply to all methods of selecting updates to decline.  Use wildcard operator (*) to match more than one update.    
    [string[]] $Products,

    #Output the list of updates to this file.    
    [string]$OutputFile="osdsusexport.xml",

    
    #Set the log file.    
    [string]$LogFile,

    #The maximum size of the log in bytes.    
    [int]$MaxLogSize = 2621440,
   
    #Define the sitecode.    
    [string]$SiteCode,

    #Define a standalone WSUS server.    
    [string]$StandAloneWSUS,

    #Define the standalone WSUS server port.    
    [int]$StandAloneWSUSPort,

    #Define the standalone WSUS server's SSL setting.    
    [bool]$StandAloneWSUSSSL = $False
)

#region Functions
Function Add-TextToCMLog {
##########################################################################################################
<#
.SYNOPSIS
   Log to a file in a format that can be read by Trace32.exe / CMTrace.exe

.DESCRIPTION
   Write a line of data to a script log file in a format that can be parsed by Trace32.exe / CMTrace.exe

   The severity of the logged line can be set as:

        1 - Information
        2 - Warning
        3 - Error

   Warnings will be highlighted in yellow. Errors are highlighted in red.

   The tools to view the log:

   SMS Trace - http://www.microsoft.com/en-us/download/details.aspx?id=18153
   CM Trace - Installation directory on Configuration Manager 2012 Site Server - <Install Directory>\tools\

.EXAMPLE
   Add-TextToCMLog c:\output\update.log "Application of MS15-031 failed" Apply_Patch 3

   This will write a line to the update.log file in c:\output stating that "Application of MS15-031 failed".
   The source component will be Apply_Patch and the line will be highlighted in red as it is an error
   (severity - 3).

#>
##########################################################################################################

#Define and validate parameters
[CmdletBinding()]
Param(
      #Path to the log file
      [parameter(Mandatory=$True)]
      [String]$LogFile,

      #The information to log
      [parameter(Mandatory=$True)]
      [String]$Value,

      #The source of the error
      [parameter(Mandatory=$True)]
      [String]$Component,

      #The severity (1 - Information, 2- Warning, 3 - Error)
      [parameter(Mandatory=$True)]
      [ValidateRange(1,3)]
      [Single]$Severity
      )


#Obtain UTC offset
$DateTime = New-Object -ComObject WbemScripting.SWbemDateTime
$DateTime.SetVarDate($(Get-Date))
$UtcValue = $DateTime.Value
$UtcOffset = $UtcValue.Substring(21, $UtcValue.Length - 21)


#Create the line to be logged
$LogLine =  "<![LOG[$Value]LOG]!>" +`
            "<time=`"$(Get-Date -Format HH:mm:ss.fff)$($UtcOffset)`" " +`
            "date=`"$(Get-Date -Format M-d-yyyy)`" " +`
            "component=`"$Component`" " +`
            "context=`"$([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)`" " +`
            "type=`"$Severity`" " +`
            "thread=`"$($pid)`" " +`
            "file=`"`">"

#Write the line to the passed log file
Out-File -InputObject $LogLine -Append -NoClobber -Encoding Default -FilePath $LogFile -WhatIf:$False

}
##########################################################################################################


#Taken from https://stackoverflow.com/questions/5648931/test-if-registry-value-exists
Function Test-RegistryValue {
##########################################################################################################
<#
.NOTES
    Taken from https://stackoverflow.com/questions/5648931/test-if-registry-value-exists
#>
    Param(
        [Alias("PSPath")]
        [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [String]$Path,
        [Parameter(Position = 1, Mandatory = $true)]
        [String]$Value,
        [Switch]$PassThru
    )

    Process {
        If (Test-Path $Path) {
            $Key = Get-Item -LiteralPath $Path
            If ($Key.GetValue($Value, $null) -ne $null) {
                If ($PassThru) {
                    Get-ItemProperty $Path $Value
                } Else {
                    $True
                }
            } Else {
                $False
            }
        } Else {
            $False
        }
    }
}
##########################################################################################################


Function Get-SiteCode {
##########################################################################################################
<#
.SYNOPSIS
   Attempt to determine the current device's site code from the registry or PS drive.

.DESCRIPTION
   When ran this function will look for the client's site.  If not found it will look for a single PS drive.

.EXAMPLE
   Get-SiteCode

#>
##########################################################################################################

    #Try getting the site code from the client installed on this system.
    If (Test-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\SMS\Identification" -Value "Site Code"){
        $SiteCode =  Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\SMS\Identification" | Select-Object -ExpandProperty "Site Code"
    } ElseIf (Test-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client" -Value "AssignedSiteCode") {
        $SiteCode =  Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client" | Select-Object -ExpandProperty "AssignedSiteCode"
    }

    #If the client isn't installed try looking for the site code based on the PS drives.
    If (-Not ($SiteCode) ) {
        #See if a PSDrive exists with the CMSite provider
        $PSDrive = Get-PSDrive -PSProvider CMSite -ErrorAction SilentlyContinue

        #If PSDrive exists then get the site code from it.
        If ($PSDrive.Count -eq 1) {
            $SiteCode = $PSDrive.Name
        }
    }

    Return $SiteCode
}
##########################################################################################################

Function Confirm-StringArray {
##########################################################################################################
<#
.SYNOPSIS
   Confirm that the string is not actually an array.

.DESCRIPTION
   If a string array is passed with a single element containing commas then split the string into an array.

#>
##########################################################################################################
    Param(
        [string[]] $StringArray
    )

    If ($StringArray){
        If ($StringArray.Count -eq 1){
            If ($StringArray[0] -ilike '*,*'){
                $StringArray = $StringArray[0].Split(",")
                Add-TextToCMLog $LogFile "The string array only had one element that contained commas.  It has been split into $($StringArray.Count) separate elements." $component 2
            }
        }
    }
    Return $StringArray
}
##########################################################################################################

Function Get-WSUSDB{
##########################################################################################################
<#
.SYNOPSIS
   Get the WSUS database configuration.

.DESCRIPTION
   Use the WSUS api to get the database configuration and verify that you can successfully connect to the DB.

#>
##########################################################################################################

    Param(
        [Parameter(Mandatory=$true)]
        [Microsoft.UpdateServices.Administration.IUpdateServer] $WSUSServer,
        [string] $LogFile ="Get-WSUSDB.log"
    )

    $component = "Get-WSUSDB"

    Try{
        $WSUSServerDB = $WSUSServer.GetDatabaseConfiguration()
    }
    Catch{
        Add-TextToCMLog $LogFile "Failed to get the WSUS database details from the active SUP." $component 3
        Add-TextToCMLog $LogFile  "Error: $($_.Exception.HResult)): $($_.Exception.Message)" $component 3
        Add-TextToCMLog $LogFile "$($_.InvocationInfo.PositionMessage)" $component 3
        Return
    }

    If (!($WSUSServerDB)){
        Add-TextToCMLog $LogFile "Failed to get the WSUS database details from the active SUP." $component 3
        Return
    }

    #This is a just a test built into the API, it's not actually making the connection we'll use.
    Try{
        $WSUSServerDB.ConnectToDatabase()
        Add-TextToCMLog $LogFile "Successfully tested the connection to the ($($WSUSServerDB.DatabaseName)) database on $($WSUSServerDB.ServerName)." $component 1
    }
    Catch{
        Add-TextToCMLog $LogFile "Failed to connect to the ($($WSUSServerDB.DatabaseName)) database on $($WSUSServerDB.ServerName)." $component 3       
        Add-TextToCMLog $LogFile "Error ($($_.Exception.HResult)): $($_.Exception.Message)" $component 3
        Add-TextToCMLog $LogFile "$($_.InvocationInfo.PositionMessage)" $component 3
        Return
    }

    Return $WSUSServerDB

}

Function Connect-WSUSDB{
##########################################################################################################
<#
.SYNOPSIS
   Connect to the WSUS database.

.DESCRIPTION
   Use the database configuration to connect to the DB.

#>
##########################################################################################################

    Param(
        [Parameter(Mandatory=$true)]
        [Microsoft.UpdateServices.Administration.IDatabaseConfiguration] $WSUSServerDB,
        [string] $LogFile = "Connect-WSUSDB.log"
    )

    $component = "Connect-WSUSDB"

    #Determine the connection string based on the type of DB being used.
    If ($WSUSServerDB.IsUsingWindowsInternalDatabase){
        #Using the Windows Internal Database.

        If (!$StandAloneWSUS){Add-TextToCMLog $LogFile "Windows Internal Database? Fer real? Come one dawg ... just stop this insanity and migrate this to your ConfigMgr SQL instance." $component 2}

        If($WSUSServerDB.ServerName -eq "MICROSOFT##WID"){
            $SqlConnectionString = "Data Source=\\.\pipe\MICROSOFT##WID\tsql\query;Integrated Security=True;Network Library=dbnmpntw"
        }
        Else{
            $SqlConnectionString = "Data Source=\\.\pipe\microsoft##ssee\sql\query;Integrated Security=True;Network Library=dbnmpntw"
        }
    }
    Else{
        #Connect to a real SQL database.
        $SqlConnectionString = "Server=$($WSUSServerDB.ServerName);Database=$($WSUSServerDB.DatabaseName);Integrated Security=True"
    }

    #Try to connect to the database.
    Try{
        $SqlConnection = New-Object System.Data.SqlClient.SqlConnection($SqlConnectionString)
	    $SqlConnection.Open()
        Add-TextToCMLog $LogFile "Successfully connected to the database." $component 1
    }
    Catch{
        Add-TextToCMLog $LogFile "Failed to connect to the database using the connection string $($SqlConnectionString)." $component 3
        Add-TextToCMLog $LogFile  "Error: $($_.Exception.HResult)): $($_.Exception.Message)" $component 3
        Add-TextToCMLog $LogFile "$($_.InvocationInfo.PositionMessage)" $component 3
        Return
    }

    Return $SqlConnection
}

#endregion

$cmSiteVersion = [version]"5.00.8540.1000"
$scriptVersion = "1.0.0"
$component = 'Invoke-OsdSusExport'
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition

#region Parameter validation
#If log file is null then set it to the default and then make the provider type explicit.
If (!$LogFile) {
    $LogFile = Join-Path $scriptPath "osdsusexport.log"
}

$LogFile = "filesystem::$($LogFile)"

#If the log file exists and is larger then the maximum then roll it over.
If (Test-path  $LogFile -PathType Leaf) {
    If ((Get-Item $LogFile).length -gt $MaxLogSize){
        Move-Item -Force $LogFile ($LogFile -replace ".$","_") -WhatIf:$False
    }
}
Add-TextToCMLog $LogFile "$component started (Version $($scriptVersion))." $component 1


#Check to make sure we're running this on a primary site server that has the SMS namespace.
If (!($StandAloneWSUS) -and !(Get-Wmiobject -namespace "Root" -class "__Namespace" -Filter "Name = 'SMS'")){
    Add-TextToCMLog $LogFile "Currently, this script must be ran on a primary site server. When the CM 1706 reaches critical mass this requirement might be removed." $component 3
    Return
}

#Make sure the stand-alone WSUS parameters make sense.
If (!$StandAloneWSUS -and ($StandAloneWSUSPort -or $StandAloneWSUSSSL)) {
    Add-TextToCMLog $LogFile "You may not use the StandAloneWSUSPort or StandAloneWSUSSSL parameters when not running against a stand-alone WSUS." $component 3
    Return
}

#If output file was given then make sure everything looks good.
If ($OutputFile){

    #If this was passed as a switch then use the default output file name.
    If (($OutputFile -is [Boolean]) -or ($OutputFile -eq 'True')){
        $OutputFile = 'OutputFile.xml'
    }

    #If this was passed as a switch then use the default output file.
    If (![System.IO.Path]::IsPathRooted($OutputFile)){
        $OutputFile = Join-Path $scriptPath $OutputFile
    }
    $OutputFile = "filesystem::$($OutputFile)"
    Write-Verbose "Output File: $OutputFile"
}

#Confirm that the string arrays are properly processed.
$Products = Confirm-StringArray $Products
#endregion

#Change the directory to the site location.
$OriginalLocation = Get-Location

#Try to load the UpdateServices module.
#NOTE: I initially tried using the WSUS Powershell module but it was exponentially slower than the API calls.  Instead of a seconds it took hours to get the update list.
Try {
    [reflection.assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration") | out-null
} Catch {
    Add-TextToCMLog $LogFile "Failed to load the UpdateServices module." $component 3
    Add-TextToCMLog $LogFile "Please make sure that WSUS Admin Console is installed on this machine" $component 3
    Add-TextToCMLog $LogFile  "Error: $($_.Exception.HResult)): $($_.Exception.Message)" $component 3
    Add-TextToCMLog $LogFile "$($_.InvocationInfo.PositionMessage)" $component 3
}

#Try and figure out WSUS connection details based on the parameters given.
If ($StandAloneWSUS){
    $WSUSFQDN = $StandAloneWSUS

    #If a port wasn't passed then set the default the port based on the SSL setting.
    If (!$StandAloneWSUSPort){
        If ($StandAloneWSUSSSL){
            $WSUSPort = 8531
        }
        Else{
            $WSUSPort = 8530
        }
    }
    Else{
        $WSUSPort = $StandAloneWSUSPort
    }

    $WSUSSSL = $StandAloneWSUSSSL

}
Else{

    #If the Configuration Manager module exists then load it.
    If (! $env:SMS_ADMIN_UI_PATH)
    {
        Add-TextToCMLog $LogFile "The SMS_ADMIN_UI_PATH environment variable is not set.  Make sure the Configuration Manager console it installed." $component 3
        Return
    }
    $configManagerCmdLetpath = Join-Path $(Split-Path $env:SMS_ADMIN_UI_PATH) "ConfigurationManager.psd1"
    If (! (Test-Path $configManagerCmdLetpath -PathType Leaf) )
    {
        Add-TextToCMLog $LogFile "The ConfigurationManager Module file could not be found.  Make sure the Configuration Manager console it installed." $component 3
        Return
    }

    #You can't pass WhatIf to the Import-Module function and it spits out a lot of text, so work around it.
    $WhatIf = $WhatIfPreference
    $WhatIfPreference = $False
    Import-Module $configManagerCmdLetpath -Force
    $WhatIfPreference = $WhatIf

    #Get the site code
    If (!$SiteCode){$SiteCode = Get-SiteCode}

    #Verify that the site code was determined
    If (!$SiteCode){
        Add-TextToCMLog $LogFile "Could not determine the site code. If you are running CAS you must specify the site code. Exiting." $component 3
        Return
    }

    #If the PS drive doesn't exist then try to create it.
    If (! (Test-Path "$($SiteCode):")) {
        Try{
            Add-TextToCMLog $LogFile "Trying to create the PS Drive for site '$($SiteCode)'" $component 1
            New-PSDrive -Name $SiteCode -PSProvider CMSite -Root "." -WhatIf:$False | Out-Null
        } Catch {
            Add-TextToCMLog $LogFile "The site's PS drive doesn't exist nor could it be created." $component 3
            Add-TextToCMLog $LogFile  "Error: $($_.Exception.HResult)): $($_.Exception.Message)" $component 3
            Add-TextToCMLog $LogFile "$($_.InvocationInfo.PositionMessage)" $component 3
            Return
        }
    }

    #Set and verify the location.
    Try{
        Add-TextToCMLog $LogFile "Connecting to site: $($SiteCode)" $component 1
        Set-Location "$($SiteCode):"  | Out-Null
    } Catch {
        Add-TextToCMLog $LogFile "Could not set location to site: $($SiteCode)." $component 3
        Add-TextToCMLog $LogFile  "Error: $($_.Exception.HResult)): $($_.Exception.Message)" $component 3
        Add-TextToCMLog $LogFile "$($_.InvocationInfo.PositionMessage)" $component 3
        Return
    }

    #Make sure the site code exists on this server.
    $CMSite = Get-CMSite -SiteCode $SiteCode
    If (!$CMSite) {
        Add-TextToCMLog $LogFile "The site code $($SiteCode) could not be found." $component 3
        Return
    }

    #Verify the site version meets the requirement.
    If ($CMSite.Version -lt $cmSiteVersion){
        Write-Warning "$($ModuleName) requires Configuration Manager $($cmSiteVersion.ToString()) or greater."
    }

    Try {

        #Determine the active SUP.
        $WSUSFQDN = (((Get-CMSoftwareUpdatePointComponent -SiteCode $SiteCode).Props) | Where-Object {$_.PropertyName -eq 'DefaultWSUS'}).Value2
        $ActiveSoftwareUpdatePoint = Get-CMSoftwareUpdatePoint -SiteCode $SiteCode -SiteSystemServerName $WSUSFQDN

        #Verify that an active SUP was found.
        If (!$ActiveSoftwareUpdatePoint){
            Add-TextToCMLog $LogFile "The active software update point ($WSUSFQDN) could not be found." $component 3
            Set-Location $OriginalLocation
            Return
        }
        Add-TextToCMLog $LogFile "The active software update point is $WSUSFQDN." $component 1

        #Determine if the active SUP is using SSL and what port.
        $WSUSSSL = (($ActiveSoftwareUpdatePoint.Props) | Where-Object {$_.PropertyName -eq 'SSLWSUS'}).Value
        $WSUSPort = 8530
        If ($WSUSSSL){
            $WSUSPort = (($ActiveSoftwareUpdatePoint.Props) | Where-Object {$_.PropertyName -eq 'WSUSIISSSLPort'}).Value
            Add-TextToCMLog $LogFile "Trying to connect to $WSUSFQDN on Port $WSUSPort using SSL." $component 1
        } Else {
            $WSUSPort = (($ActiveSoftwareUpdatePoint.Props) | Where-Object {$_.PropertyName -eq 'WSUSIISPort'}).Value
            Add-TextToCMLog $LogFile "Trying to connect to $WSUSFQDN on Port $WSUSPort." $component 1
        }
    }
    Catch {
        Add-TextToCMLog $LogFile "Failed to determine the active software update point." $component 3
        Add-TextToCMLog $LogFile  "Error: $($_.Exception.HResult)): $($_.Exception.Message)" $component 3
        Add-TextToCMLog $LogFile "$($_.InvocationInfo.PositionMessage)" $component 3
        $WSUSServer = $null
        Set-Location $OriginalLocation
        Return
    }
} #If Not StandAloneWSUS

Try{
    $WSUSServer = [Microsoft.UpdateServices.Administration.AdminProxy]::GetUpdateServer($WSUSFQDN, $WSUSSSL, $WSUSPort)
} Catch {

    Add-TextToCMLog $LogFile "Failed to connect to the WSUS server $WSUSFQDN on port $WSUSPort with$(If(!$WSUSSSL){"out"}) SSL." $component 3
    Add-TextToCMLog $LogFile  "Error: $($_.Exception.HResult)): $($_.Exception.Message)" $component 3
    Add-TextToCMLog $LogFile "$($_.InvocationInfo.PositionMessage)" $component 3
    $WSUSServer = $null
    Set-Location $OriginalLocation
    Return
}

#If the WSUS object is not instantiated then exit.
If ($WSUSServer -eq $null) {
    Add-TextToCMLog $LogFile "Failed to connect." $component 3
    Add-TextToCMLog $LogFile "Please make sure that WSUS Admin Console is installed on this machine" $component 3
    Set-Location $OriginalLocation
    Return
 }

Add-TextToCMLog $LogFile "Connected to WSUS server $WSUSFQDN." $component 1

    $WSUSServerDB = Get-WSUSDB $WSUSServer $LogFile
    If(!$WSUSServerDB)
    {
	    Add-TextToCMLog $LogFile "Failed to get the WSUS database configuration." $component 3
        Set-Location $OriginalLocation
        Return
    }
    
    $UpdateScope = new-object Microsoft.UpdateServices.Administration.UpdateScope
    $UpdateScope.TextIncludes = $Title
    
    if ($Products.Count -gt 0)
    {
        $UpdateCategoryCollection = New-Object Microsoft.UpdateServices.Administration.UpdateCategoryCollection
        $UpdateCategories = $WSUSServer.GetUpdateCategories()
        
        foreach( $UpdateCategory in $UpdateCategories)
        {
            foreach ($product in $Products)
            {                
                if ($UpdateCategory.Title -eq $product)
                {
                    Add-TextToCMLog $LogFile "Adding product to search: $product." $component 1
                    $UpdateScope.Categories.Add($UpdateCategory) | Out-Null
                }
            }
        }        
    }

    #Get a collection of all updates.
    Add-TextToCMLog $LogFile "Retrieving updates." $component 1
    Try {
	    $AllUpdates = $WSUSServer.GetUpdates($UpdateScope)
    } Catch {
	    Add-TextToCMLog $LogFile "Failed to get updates." $component 3
        Add-TextToCMLog $LogFile "If this operation timed out, try running the script with only the FirstRun parameter." $component 3
        Add-TextToCMLog $LogFile  "Error: $($_.Exception.HResult)): $($_.Exception.Message)" $component 3
        Add-TextToCMLog $LogFile "$($_.InvocationInfo.PositionMessage)" $component 3
	    Set-Location $OriginalLocation
	    Return
    }
    
    Add-TextToCMLog $LogFile "Retrieved list of $($AllUpdates.Count) updates." $component 1

    $output = $AllUpdates | ConvertTo-Xml -NoTypeInformation
    $output.OuterXml | Out-File -FilePath $OutputFile

Add-TextToCMLog $LogFile "$component finished." $component 1
Add-TextToCMLog $LogFile "#############################################################################################" $component 1
Set-Location $OriginalLocation
Write-Output "The script completed successfully.  Review the log file for detailed results."