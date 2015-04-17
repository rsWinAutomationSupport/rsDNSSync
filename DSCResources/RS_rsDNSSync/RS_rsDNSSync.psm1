. (Get-rsSecrets)
function Get-TargetResource{
    
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
                foreach($record in Get-DnsServerResourceRecord -ZoneName showpitch | ? RecordType -eq A){
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

}