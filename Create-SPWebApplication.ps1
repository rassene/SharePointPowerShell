Function Create-DNSRecord([string] $DNSServer, [string] $DNSZone, [string] $DNSRecord, [string] $DNSRecordType, [string] $IPAddress) {
    If ((Check-DNSRecordExists $DNSServer $DNSZone $DNSRecord $DNSRecordType) -eq $false) {
        Invoke-Expression "dnscmd $DNSServer /RecordAdd $DNSZone $DNSRecord $DNSRecordType $IPAddress";
        Write-Host "Created record for $DNSRecord";
    } Else {
        Write-Host "DNS entry already exists for $DNSRecord";
    }        
}

Function Check-DNSRecordExists([string] $DNSServer, [string] $DNSZone, [string] $DNSRecord, [string] $DNSRecordType) {
    $dnscmdResponse = Invoke-Expression "dnscmd $DNSServer /EnumRecords $DNSZone $DNSRecord /Type $DNSRecordType";
    If ($dnscmdResponse[1].ToString().Contains("failed") -eq $true) { Return $false; }
    Else { Return $true; }
}

Function Create-SPWebApplication([string] $DNSRecord, [string] $DNSZone, [int] $port, [string] $appPool, [string] $appPoolCredentials,
                                    [string] $databaseServer, [string] $databaseName, [string] $authenticationMethod) {
    $Name = "SharePoint - $DNSRecord";
    $HostHeader = "$DNSRecord.$DNSZone";
    $URL = "https://$hostHeader";
    $ap = New-SPAuthenticationProvider;
    
    If(Check-AppPoolExists $AppPool) {
        New-SPWebApplication -Name $name -HostHeader $hostHeader -Port $port -URL $url -ApplicationPool $appPool `
                                -DatabaseName $databaseName -DatabaseServer $databaseServer -AuthenticationMethod $authenticationMethod `
                                -AuthenticationProvider $ap -SecureSocketsLayer
    } Else {
        New-SPWebApplication -Name $name -HostHeader $hostHeader -Port $port -URL $url `
                                -ApplicationPool $appPool -ApplicationPoolAccount (Get-SPManagedAccount $AppPoolCredentials) `
                                -DatabaseName $databaseName -DatabaseServer $databaseServer -AuthenticationMethod $authenticationMethod `
                                -AuthenticationProvider $ap -SecureSocketsLayer
    }

    Write-Host "Created $Name";
}

Function Check-AppPoolExists([string] $AppPool) {
    $Result = Get-SPWebApplication | Where { $_.ApplicationPool.Name -eq $AppPool }
    If($Result) {
        Return $true;
    } Else {
        Return $false;
    }
}

Add-PsSnapin Microsoft.SharePoint.PowerShell -ea SilentlyContinue

$DNSRecord = "mvasample";
$Template = "DEV#0";
$Owner = "GEEKTRAINER\charrison";

$DNSServer = "geektrainerdc.geektrainer.com";
$DNSZone = "sharepoint2013.com";
$IPAddress = "192.168.42.21";
$DNSRecordType = "A";

$Name = "SharePoint - $DNSRecord";
$AppPool = "SharePoint 2013 - Web Sites";
$AppPoolCredentials = "GEEKTRAINER\sp2013service";

$DatabaseServer = "sql2012primary.geektrainer.com\sharepoint";
$DatabaseName = "SharePoint_{0}_Content" -f $DNSRecord;
$AuthenticationMethod = "NTLM";

$HostHeader = "{0}.{1}" -f $DNSRecord, $DNSZone;
$URL = "https://$hostheader";
$Port = 443;

$SiteName = $DNSRecord;
$Description = $DNSRecord;

Create-DNSRecord $DNSServer $DNSZone $DNSRecord $DNSRecordType $IPAddress;

Create-SPWebApplication $DNSRecord $DNSZone $Port $AppPool $AppPoolCredentials $DatabaseServer $DatabaseName $AuthenticationMethod

$site = New-SPSite $URL -OwnerAlias $Owner -Language 1033 -Template $Template -Name $SiteName -Description $Description;

#Create the default groups
$site.RootWeb.CreateDefaultAssociatedGroups($Owner, "", $SiteName);
$site.RootWeb.Update();