###########################################################
#			Send data as HTML with mail
###########################################################

<#
Requires the following permissions:
    Mail.Send

Edit the value on line 35 to be whatever data you want to send. 
Edit the Sender, Recipient and subject on line 42, 43 and 45 as well. 
#>

$HtmlOutput = @()

$Style = @"
<style>
    table {
        border-collapse: collapse;
        width: 100%;
        font-family: Arial, sans-serif;
        font-size: 12px;
    }
    th, td {
        border: 1px solid #ddd;
        padding: 8px;
        text-align: left;
    }
    th {
        background-color: #f2f2f2;
    }
</style>
"@

$HtmlOutput += $Style
$HtmlOutput += $WHATEVER_DATA_YOU_WANT_TO_SEND
$HtmlOutput | ConvertTo-Html -As Table -Fragment | Out-String

$Length = ($HtmlOutput | Measure-Object -Character).Characters

If ($Length -gt 338) {
    # Email details
    $Sender = ""
    $Recipient = ""
    #$CcRecipient = ""
    $Subject = "Something relevant"
    $Body = "$HtmlOutput"
    $Type = "HTML"
    $Save = "true"

    $Params = @{
        Message = @{
            Subject = $Subject
            Body    = @{
                ContentType = $Type
                Content     = $Body
            }
            ToRecipients = @(
                @{
                    EmailAddress = @{
                        Address = $Recipient
                    }
                }
            )
            #CcRecipients = @(
            #    @{
            #        EmailAddress = @{
            #            Address = $CcRecipient
            #        }
            #    }
            #)
        }
        SaveToSentItems = $Save
    }

    Send-MgUserMail -UserId $Sender -BodyParameter $Params

}
