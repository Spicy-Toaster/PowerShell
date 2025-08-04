$MailOutput = @()

#Connect to get secrets expiration
Connect-MgGraph -CertificateThumbprint "" -ApplicationId "" -TenantId "" 

$DaysUntilExpiration = 30
$Now = Get-Date

$Applications = Get-MgApplication -all
$SecretOverview = @()
$CertOverview = @()
$SAMLOverview = @()

foreach ($App in $Applications) {
    $AppName = $App.DisplayName
    $AppID = $App.Id
    $ApplID = $App.AppId

    $AppCreds = Get-MgApplication -ApplicationId $AppID | Select-Object PasswordCredentials, KeyCredentials

    $Secrets = $AppCreds.PasswordCredentials
    $Certs = $AppCreds.KeyCredentials

    foreach ($Secret in $Secrets) {
        $StartDate = $Secret.StartDateTime
        $EndDate = $Secret.EndDateTime
        $SecretName = $Secret.DisplayName
        $TempAppStart = $StartDate -split (" ")
        $TempAppEnd = $EndDate -split (" ")

try {
    $Owner = Get-MgApplicationOwner -ApplicationId $App.Id
    if ($Owner.AdditionalProperties.'@odata.type' -eq '#microsoft.graph.user') {
        $User = Get-MgUser -UserId $Owner.Id
        $UserName = $User.DisplayName
    } else {
        $UserName = $null
    }
} catch {
    $UserName = $null
}



        $RemainingDaysCount = ($EndDate - $Now).Days
        if ($RemainingDaysCount -le $DaysUntilExpiration -and $RemainingDaysCount -ge 0 -and $TempAppStart[0] -ne $TempAppEnd[0]) {
            $SecretOverview += [PSCustomObject]@{
                'ApplicationName'   = $AppName
                'ApplicationID'     = $ApplID
                'Secret Name'       = $SecretName
                'Secret Start Date' = $StartDate
                'Secret End Date'   = $EndDate
                'Owner'             = $Username
            }
        }
    }

    foreach ($Cert in $Certs) {
        $StartDate = $Cert.StartDateTime
        $EndDate = $Cert.EndDateTime
        $CertName = $Cert.DisplayName

try {
    $Owner = Get-MgApplicationOwner -ApplicationId $App.Id
    if ($Owner.AdditionalProperties.'@odata.type' -eq '#microsoft.graph.user') {
        $User = Get-MgUser -UserId $Owner.Id
        $UserName = $User.DisplayName
    } else {
        $UserName = $null
    }
} catch {
    $UserName = $null
}

        $RemainingDaysCount = ($EndDate - $Now).Days

        if ($RemainingDaysCount -le $DaysUntilExpiration -and $RemainingDaysCount -ge 0) {
            $CertOverview += [PSCustomObject]@{
                'ApplicationName'        = $AppName
                'ApplicationID'          = $ApplID
                'Certificate Name'       = $CertName
                'Certificate Start Date' = $StartDate
                'Certificate End Date'   = $EndDate
                'Owner'                  = $Username
            }

        }
    }
}

#Get expiration data for SAML certificates
$AllSPs = Get-MgBetaServicePrincipal  -All
$SamlSPs = $allSPs | Where-Object PreferredTokenSigningKeyEndDateTime

foreach ($SamlSP in $SamlSPs) {
    $EndDate = $SamlSP.PreferredTokenSigningKeyEndDateTime
    $SAMLName = $SamlSP.DisplayName
}

$RemainingDaysCount = ($EndDate - $Now).Days
if ($RemainingDaysCount -le $DaysUntilExpiration -and $RemainingDaysCount -ge 0) {
    $SAMLOverview += [PSCustomObject]@{
        'ApplicationName' = $SAMLName
        'ApplicationID'   = $SamlSP.AppId
        'Cert Name'       = "Token signing certificate"
        'Secret End Date' = $EndDate

    }
}




#Convert $MailOutput to a string as that is what email can handle 
$MailOutput += $SecretOverview
$MailOutput += $CertOverview
$MailOutput += $SAMLOverview
$StringMailOutput = $MailOutput | Out-String
