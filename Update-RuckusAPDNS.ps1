param (
    [Parameter(Mandatory=$true)]$SmartZoneURI,
    [Parameter(Mandatory=$true)]$DNS1,
    [Parameter(Mandatory=$true)]$DNS2
)

$credentials = Get-Credential -Message "Admin account of your SmartZone Controller"

$uri = "https://"+$SmartZoneURI:8443+"/wsg/api/public"
$logonuri = $uri+"/v8_1/session"

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Content-Type", "application/json;charset=UTF-8")

#logon
$body = @{"username"=$credentials.UserName;
    "password"=$Credentials.GetNetworkCredential().Password;
    "timeZoneUtcOffset"="-05:00"
    }

$json = $body | ConvertTo-Json


###Requesting a web sessions and adding the cookie to the header file doesn't work in Windows PowerShell 5.1
###Instead we must use HTTPWebRequest from .NET and pass that session to all the subsequent PowerShell commands.
$webrequest = Invoke-WebRequest -Uri $logonuri -Headers $headers -Body $json -Method Post -SessionVariable websession

###Get all the APs on the controller###
$index = 0
$aps = @()
$apsuri = $uri+"/v8_1/aps?index=$index"

do {
    $response = Invoke-RestMethod -Method Get -Uri $apsuri -WebSession $websession -Headers $headers
    $aps += $response.list
    $index += 100
    $apsuri = $uri+"/v8_1/aps?index=$index"

} while ($response.hasMore)


###Update all the APs with new DNS settings
#$DNS1 = "1.1.1.1"
#$DNS2 = "1.0.0.1"

foreach ($ap in $aps){
    $apuri = $uri+"/v8_1/aps/"+$ap.mac
    $ap = Invoke-RestMethod -Method Get -Uri $apuri -WebSession $websession -Headers $headers
    $oldnetwork = $ap.network
        
    if ($oldnetwork.ipType -eq "Static") {
        $newnetwork = @{
            "ipType"="Static";
            "ip"=$oldnetwork.ip;
            "netmask"=$oldnetwork.netmask;
            "gateway"=$oldnetwork.gateway;
            "primaryDns"=$DNS1;
            "secondaryDns"=$DNS2
        }

        $networkjson = $newnetwork | ConvertTo-Json

        $networkuri = $apuri+"/network"
        Write-Host "Updating $($ap.name)"
        Invoke-RestMethod -Method Patch -Uri $networkuri -WebSession $websession -Headers $headers -Body $networkjson

        Remove-Variable networkjson
    } else {
        Write-Host "$($ap.name) is not using static IP settings"
        $notstatic += $ap

    }
}
