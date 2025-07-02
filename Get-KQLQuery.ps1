###########################################################
#			KQL report in PowerShell
###########################################################

<#
Requires the following permissions
		ThreatHunting.Read.All
		
Edit the values on line 14 
#>

$Output = @()

$Query = "INSERT KQL QUERY HERE"

$Result = Start-MgSecurityHuntingQuery -Query $Query

# Initialize an empty array to store results
$ResultsArray = @()

# Extract keys in the order they appear in the first result
$Keys = $Result.Results[0].AdditionalProperties.Keys

# Collect any additional unique keys from other results while preserving order
$AllKeys = $Keys + (($Result.Results.AdditionalProperties | ForEach-Object { $_.Keys }) | Where-Object { $Keys -notcontains $_ } | Select-Object -Unique)

# Iterate through each result and construct PSCustomObject dynamically
$Result.Results | ForEach-Object {
    $Obj = @{}
    foreach ($Key in $AllKeys) {
        $Obj[$Key] = $_.AdditionalProperties[$Key]
    }
    $Output += [PSCustomObject]$Obj
}
