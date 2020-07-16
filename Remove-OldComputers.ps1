[cmdletbinding()]
param(
    [Parameter(Mandatory=$true)][string]$SiteCode,
    [Parameter(Mandatory=$true)][string]$Server
)

BEGIN{

    $startlocation = Get-Location
    $initParams = @{}
    #$initParams.Add("Verbose", $true) # Uncomment this line to enable verbose logging
    #$initParams.Add("ErrorAction", "Stop") # Uncomment this line to stop the script on any errors

    # Do not change anything below this line

    # Import the ConfigurationManager.psd1 module 
    if((Get-Module ConfigurationManager) -eq $null) {
        Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" @initParams 
    }

    # Connect to the site's drive if it is not already present
    if((Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
        New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $Server @initParams
    }

    # Set the current location to be the site code.
    Set-Location "$($SiteCode):\" @initParams

    try{
        import-module ActiveDirectory -ErrorAction Stop
    } catch {
        Write-Error "ActiveDirectory module no installed. Please install AD RSAT tools first."
        break;
    }

}

PROCESS{
    #Get all devices in SCCM, check and see if an AD object exists for them, and delete the ones that don't
    $devices = Get-WmiObject -ComputerName $Server -Namespace "ROOT\SMS\Site_$SiteCode" -Class SMS_R_System
    $exists = @()
    $doesntexist = @()
    $doesntexist2 = @()

    $total = $devices.count
    $count = 0
    foreach ($device in $devices) {
        $count++
        Write-Progress -Activity "Checking computers" -PercentComplete (($count/$total)*100) -Status "$count out of $total devices processed"
        try {
            $sid = new-object System.Security.Principal.SecurityIdentifier($device.SID)
        } catch {}

        #$sid
        $ADcomputer = Get-ADComputer -Filter {SID -eq $sid}
        if ($ADcomputer) {
            $exists += $device
        } else {
            $doesntexist += $device
            Remove-CMResource -ResourceId $device.ResourceId -Force
        }
        Remove-Variable sid
        Remove-Variable ADcomputer


    }
}

END{
    
    Set-Location $startlocation

}