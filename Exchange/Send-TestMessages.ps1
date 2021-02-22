$cred = get-credential
$body = “Just a test email”

for ($i = 0; $i -le 30; $i++) {
    $subjectLine = "Test " + $i
    Send-MailMessage -To dogvalley@innit.tech -from dogvalley@innit.tech -Subject $subjectLine -Body $body -BodyAsHtml -smtpserver smtp.office365.com -usessl -Credential $cred -Port 587
}
