$VC = "cph-vc03-p.dk.flsmidth.net"
Get-Credential | Export-Clixml $env:userprofile\$env:username.clixml
$UserCred = Import-clixml "$credPathName\$credFileName"
Connect-VIServer -Server $VC -Credential $UserCred


if (!(Test-Path $env:userprofile\$env:username.clixml)) {
    Get-Credential | Export-Clixml $env:userprofile\$env:username.clixml
   }