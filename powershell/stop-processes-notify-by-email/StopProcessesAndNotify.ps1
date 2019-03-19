# Variables
$TeamsChannel = '5ff3973e.homegroup.org.uk@emea.teams.ms'
$Now = Get-Date -format "dd-MMM-yyyy HH:mm"
 
# E-mail specific variables
$EmailAddress = $env:USERNAME + '@group.homegroup.org.uk'
 
$EmailSMTPServer = "smtp.office365.com"
$EmailSMTPServerPort = "587"
$EmailSMTPUsername = $EmailAddress
$EmailSMTPPassword = Get-Content "C:\Users\$env:USERNAME\Documents\EmailCreds.txt" | ConvertTo-SecureString
 
$EmailObject = New-Object System.Net.Mail.MailMessage
$EmailObject.From = $EmailAddress
$EmailObject.To.Add( $TeamsChannel )
$EmailObject.Subject = "Inaport: Broken process found"
$EmailObject.IsBodyHtml = $true
$EmailObject.Body = '<p style="margin: 10px 0;">The <strong>StopInaportProcessesAndNotify.ps1</strong> script has detected an erroneous Inaport process which has now been terminated.</p><p style="margin: 10px 0;">This script ran at <strong>' + $Now + '</strong>.</p>'
 
$SMTPObject = New-Object System.Net.Mail.SmtpClient( $EmailSMTPServer , $EmailSMTPServerPort )
$SMTPObject.EnableSsl = $true
$SMTPObject.Credentials = New-Object System.Net.NetworkCredential( $EmailSMTPUsername , $EmailSMTPPassword );
 
# Get all processes with a name like "inaport"
$InaportProcesses = Get-Process inaport
 
# If such processes exist, do something...
If( $InaportProcesses.Count -gt 0 ) {
    # Initialise error count variable
    $ProcessStopErrors = @()
    $InaportProcesses | ForEach-Object {
        # Attempt to kill
        Try {
            Stop-Process $_ -Force -ErrorAction Stop
        }
        Catch {
            $ProcessStopErrors += $_.Exception.Message
        }
    }
 
    # If we haven't been able to kill one or more of the processes, let the DevOps team know
    If( $ProcessStopErrors.Count -gt 0 ) {
        $EmailObject.Body += '<p style="margin: 10px 0; color: #FF0000;">The Inaport process could not be killed. Error messages: <ul>'
 
        # Add the exact error details to the e-mail
        ForEach( $ProcessStopError in $ProcessStopErrors ) {
            $EmailObject.Body += '<li>' + $ProcessStopError + '</li>'
        }
 
        $EmailObject.Body += '</ul></p>'
    }
 
    # Send an e-mail to Teams channel
    $SMTPObject.Send( $EmailObject )
}