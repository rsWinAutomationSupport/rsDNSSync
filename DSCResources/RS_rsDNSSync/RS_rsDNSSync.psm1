. (Get-rsSecrets)
function Get-TargetResource{
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        $AdapterName = "Public",
        [ValidateSet("CloudServer","CloudDNS")]
        $DNSProvider = "CloudServer",
        [Parameter(Mandatory = $true)]
        $ZoneName
    )

    switch($DNSProvider){
        CloudServer{
            $localDNSPresent = (Get-WindowsFeature DNS).Installed
            if($localDNSPresent -eq $true){
                if((Get-DnsServerZone $ZoneName -ErrorAction SilentlyContinue) -ne $null){
                    $localRecords = @()
                    foreach($record in Get-DnsServerResourceRecord -ZoneName $ZoneName | ? RecordType -eq A){
                        $recordEnum = New-Object psobject -Property @{'name'=$record.HostName;'RecordData'=$record.RecordData.IPv4Address.IPAddressToString}
                        $localRecords += $recordEnum
                    }
                }
            }
        }
        CloudDNS{

        }
    }
    else{$localRecords = $null}
    $cloudRecords = Get-rsCloudServersInfo | select name,@{n="RecordData";e={$_.addresses.$AdapterName.addr}}

    @{
        "DNSProvider" = $DNSProvider
        "localDNSPresent" = $localDNSPresent
        "ZoneName" = $ZoneName
        "TargetAdapter" = $AdapterName
        "CloudServers" = $cloudRecords
        "LocalRecords" = $localRecords
    }
}
function Test-TargetResource{
    param(
        $AdapterName = "Public",
        [ValidateSet("CloudServer","CloudDNS")]
        $DNSProvider = "CloudServer",
        [Parameter(Mandatory = $true)]
        $ZoneName
    )

    $cloudRecords = Get-rsCloudServersInfo | select name,@{n="RecordData";e={$_.addresses.$AdapterName.addr}}

    switch($DNSProvider){
        CloudServer{
            if(!(Get-WindowsFeature DNS).Installed){Return $false}
            elseif((Get-DnsServerZone $ZoneName -ErrorAction SilentlyContinue) -eq $null){Return $false}
            else{
                $localRecords = @()
                foreach($record in Get-DnsServerResourceRecord -ZoneName $ZoneName | ? RecordType -eq A){
                    $recordEnum = New-Object psobject -Property @{'name'=$record.HostName;'RecordData'=$record.RecordData.IPv4Address.IPAddressToString}
                    $localRecords += $recordEnum
                }
                if($localRecords -ne $cloudRecords){Return $false}
                else{Return $true}
            }
        }
        CloudDNS{

        }
    }
}
function Set-TargetResource{
    param(
        $AdapterName = "Public",
        [ValidateSet("CloudServer","CloudDNS")]
        $DNSProvider = "CloudServer",
        [Parameter(Mandatory = $true)]
        $ZoneName
    )

    $cloudRecords = Get-rsCloudServersInfo | select name,@{n="RecordData";e={$_.addresses.$AdapterName.addr}}

    switch($DNSProvider){
        CloudServer{
            if(!(Get-WindowsFeature DNS).Installed){
                Install-WindowsFeature DNS -IncludeManagementTools
            }
            if((Get-DnsServerZone $ZoneName -ErrorAction SilentlyContinue) -eq $null){
                Add-DnsServerPrimaryZone -Name $ZoneName -ZoneFile ($ZoneName + ".dns")
            }

            $localRecords = @()
            foreach($record in Get-DnsServerResourceRecord -ZoneName showpitch | ? RecordType -eq A){
                $recordEnum = New-Object psobject -Property @{'name'=$record.HostName;'RecordData'=$record.RecordData.IPv4Address.IPAddressToString}
                $localRecords += $recordEnum
            }
            
            foreach($record in $cloudRecords){
                if($localRecords -notcontains ($record.name -and $record.RecordData)){
                    Add-DnsServerResourceRecord -ZoneName $ZoneName -A -Name $record.name -IPv4Address $record.RecordData
                }
            }
            foreach($record in $localRecords){
                if($cloudRecords -notcontains ($record.name -and $record.RecordData)){
                    Remove-DnsServerResourceRecord -ZoneName $ZoneName -RRType A -Name $record.name -RecordData $record.RecordData
                }
            }
        }
        CloudDNS{

        }
    }
}