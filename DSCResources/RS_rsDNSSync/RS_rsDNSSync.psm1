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
            else{$localRecords = $null}
        }
        CloudDNS{

        }
    }
    $cloudRecords = Get-rsCloudServersInfo | select name,@{n="RecordData";e={$_.addresses.$AdapterName.addr}}

    @{
        "DNSProvider" = $DNSProvider
        #"localDNSPresent" = $localDNSPresent
        "ZoneName" = $ZoneName
        "TargetAdapter" = $AdapterName
        #"CloudServers" = $cloudRecords
        #"LocalRecords" = $localRecords
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

    $cloudRecords = Get-rsCloudServersInfo | select name,@{n="RecordData";e={$_.addresses.$AdapterName.addr}} | sort RecordData

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
                $localRecords = $localRecords | sort RecordData
                if($localRecords.Count -eq 0){Write-Verbose "Local Zone $($ZoneName) contains no records."; Return $false}
                $cloudArray = $cloudRecords
                foreach($record in $localRecords){
                    if(($cloudRecords.name.Contains($record.name)) -and ($cloudRecords.RecordData.Contains($record.RecordData))){
                        Write-Verbose "Target match found for $($record.name): $($record.RecordData)"
                        $cloudArray = $cloudArray | ? name -ne $record.name
                    }
                    else{
                        Write-Verbose "Target match found for $($record.name): $($record.RecordData)"
                    }
                }
                $localArray = $localRecords
                foreach($record in $cloudRecords){
                    if(($localRecords.name.Contains($record.name)) -and ($localRecords.RecordData.Contains($record.RecordData))){
                        Write-Verbose "Target match found for $($record.name): $($record.RecordData)"
                        $localArray = $localArray | ? name -ne $record.name
                    }
                    else{
                        Write-Verbose "Target match not found for $($record.name): $($record.RecordData)"
                    }
                }
                if(($cloudArray -ne $null) -or ($localArray -ne $null)){Write-Verbose "One or more DNS records are out of Sync"; Return $false}
                else{Write-Verbose "Servers in API match records in Local DNS Server"; Return $true}
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
                Write-Verbose "Installing DNS Server"
                Install-WindowsFeature DNS -IncludeManagementTools
            }
            if((Get-DnsServerZone $ZoneName -ErrorAction SilentlyContinue) -eq $null){
                Write-Verbose "Creating DNS Zone $($ZoneName)"
                Add-DnsServerPrimaryZone -Name $ZoneName -ZoneFile ($ZoneName + ".dns")
            }

            $localRecords = @()
            foreach($record in Get-DnsServerResourceRecord -ZoneName $ZoneName | ? RecordType -eq A){
                $recordEnum = New-Object psobject -Property @{'name'=$record.HostName;'RecordData'=$record.RecordData.IPv4Address.IPAddressToString}
                $localRecords += $recordEnum
            }

            $cloudArray = $cloudRecords
            foreach($record in $localRecords){
                if(($cloudRecords.name.Contains($record.name)) -and ($cloudRecords.RecordData.Contains($record.RecordData))){
                    $cloudArray = $cloudArray | ? name -ne $record.name
                }
            }
            if(($localRecords -ne $null) -or ($localRecords.count -ne 0)){
                $localArray = $localRecords
                foreach($record in $cloudRecords){
                    if(($localRecords.name.Contains($record.name)) -and ($localRecords.RecordData.Contains($record.RecordData))){
                        $localArray = $localArray | ? name -ne $record.name
                    }
                }
            }
            if($cloudArray -ne $null){
                foreach($record in $cloudArray){
                    Write-Verbose "Adding $($record.name): $($record.RecordData) to local zone $($ZoneName)"
                    Add-DnsServerResourceRecord -ZoneName $ZoneName -A -Name $record.name -IPv4Address $record.RecordData
                }
            }
            if($localArray -ne $null){
                foreach($record in $localArray){
                    Write-Verbose "Removing $($record.name): $($record.RecordData) from local zone $($ZoneName)"
                    Remove-DnsServerResourceRecord -ZoneName $ZoneName -RRType A -Name $record.name -RecordData $record.RecordData -Force
                }
            }
        }
        CloudDNS{

        }
    }
}