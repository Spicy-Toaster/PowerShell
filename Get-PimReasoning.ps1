###########################################################
#			PIM reasoning audit
###########################################################

<#
Requires the following permissions
	AuditLog.Read.All
	Group.Read.All
	RoleManagement.Read.Directory
	User.Read.All
	
Edit the values on line 22 (how many days back you want to review) and line 28 (what users you want to search for based on prefix)
#>

$TenantId = ""
$ClientId = ""
$Thumbprint = ""

Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -CertificateThumbprint $Thumbprint

# Define time window for yesterday
$TimeFrame = "1"  # Number of days back to look 
$Now       = Get-Date
$StartTime = $Now.AddDays(-$TimeFrame).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")  # Start of the timeframe
$EndTime   = $Now.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")                       # End of the timeframe (now)

# Get the target users whose UPNs start with a specific prefix
$Prefix = ""
$UserUPNs = Get-MgUser -Filter "startsWith(userPrincipalName,'$Prefix')" -All

# Initialize output collection and a cache for resource display names
$Output = @()
$ResourceCache = @{}

foreach ($User in $UserUPNs) {
    # Filter logs so we dont pull way too much data
    $Filter = "initiatedBy/user/id eq '$($User.Id)' and loggedByService eq 'PIM' and operationType eq 'Update' and result eq 'success' and activityDateTime ge $StartTime and activityDateTime lt $EndTime"
    $Logs = Get-MgAuditLogDirectoryAudit -Filter $Filter -All

    # Further refine logs to exclude unwanted activity types and empty reasons. This can't be filtered with the above filter so we are forced to have two filters
    $FilteredLogs = $Logs | Where-Object {
        $_.ActivityDisplayName -notmatch "Remove" -and
        $_.ActivityDisplayName -notmatch "Requested" -and
        $_.activityDisplayName -notmatch "Update role setting in PIM" -and
        $_.activityDisplayName -notmatch "Add eligible member to role in PIM completed" -and
        -not [string]::IsNullOrWhiteSpace($_.ResultReason)
    }

    foreach ($Log in $FilteredLogs) {
        # Classify the type of PIM action. Just to make it more classy
        $PimType = switch ($Log.Category) {
            "RoleManagement"     { "PIM for roles" }
            "GroupManagement"    { "PIM for groups" }
            "ResourceManagement" { "PIM for resources" }
            default              { $Log.Category }
        }

        foreach ($Resource in $Log.TargetResources) {
            if ($Resource.DisplayName -and $Resource.Id) {
                $TargetResource = $null

                # Check if resource display name is already cached
                if ($ResourceCache.ContainsKey($Resource.Id)) {
                    $TargetResource = $ResourceCache[$Resource.Id]
                }
                else {
                    try {
                        # Try to resolve as a group
                        $Group = Get-MgGroup -GroupId $Resource.Id -ErrorAction Stop
                        $TargetResource = $Group.DisplayName
                    }
                    catch {
                        try {
                            # Try to resolve as a directory role
                            $Role = Get-MgDirectoryRole -DirectoryRoleId $Resource.Id -ErrorAction Stop
                            $TargetResource = $Role.DisplayName
                        }
                        catch {
                            # If both fail, leave as null
                            $TargetResource = $null
                        }
                    }
                    # Store in cache regardless of result (null is fine too)
                    $ResourceCache[$Resource.Id] = $TargetResource
                }

                if ($TargetResource) {
                    $CorrelationId = $Log.CorrelationId
                    $ApprovedBy = ""

                    if ($CorrelationId) {
                        try {
                            # Try to find a related approval log using the correlation ID
                            $RelatedLog = Get-MgAuditLogDirectoryAudit -Filter "correlationId eq '$CorrelationId' and activityDisplayName eq 'Add member to role request approved (PIM activation)'" -All

                            if ($RelatedLog -and $RelatedLog.InitiatedBy.User.DisplayName) {
                                $ApprovedBy = $RelatedLog.InitiatedBy.User.DisplayName
                            }
                        }
                        catch {
                            # Do nothing; default to ""
                        }
                    }

                    # Add result to the final output
                    $Output += [PSCustomObject]@{
                        Time           = $Log.ActivityDateTime
                        Requester      = $User.DisplayName
                        PimType        = $PimType
                        TargetResource = $TargetResource
                        Reason         = $Log.ResultReason
                        Approver       = $ApprovedBy
                    }
                }
            }
        }
    }
}
