. (Get-rsSecrets)
function GetLocalRecords{
    param(
        $ZoneName
    )

    $localRecords = @()
    foreach($record in Get-DnsServerResourceRecord -ZoneName $ZoneName | ? RecordType -eq A){
        $recordEnum = New-Object psobject -Property @{'name'=$record.HostName;'RecordData'=$record.RecordData.IPv4Address.IPAddressToString}
        $localRecords += $recordEnum
    }
    $localRecords = $localRecords | sort RecordData
    Return $localRecords
}
function CompareRecords{
    param(
        $records,
        $foreignRecords
    )

    $recordArray = $foreignRecords

    foreach($record in $records){
        if(($foreignRecords.name.Contains($record.name)) -and ($foreignRecords.RecordData.Contains($record.RecordData))){
            Write-Verbose "Target match found for $($record.name): $($record.RecordData)"
            $recordArray = $recordArray | ?{$_ -notmatch $record}
        }
        else{
            Write-Verbose "Target match not found for $($record.name): $($record.RecordData)"
        }
    }
    Return $recordArray
}
function SyncRecords{
    param(
        [ValidateSet("SyncToLocal","SyncToCloud")]
        $SyncDirection,
        $HostName,
        $RecordData,
        $ZoneName
    )

    switch($SyncDirection){
        SyncToLocal{
            Add-DnsServerResourceRecord -ZoneName $ZoneName -A -Name $HostName -IPv4Address $RecordData -Verbose
        }
        SyncToCloud{
            Remove-DnsServerResourceRecord -ZoneName $ZoneName -RRType A -Name $HostName -RecordData $RecordData -Force -Verbose
        }
    }
}
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

    @{
        "DNSProvider" = $DNSProvider
        "ZoneName" = $ZoneName
        "AdapterName" = $AdapterName
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

    $cloudRecords = Get-rsCloudServersInfo | ? status -eq "ACTIVE" | select @{n="name";e={$_.name.tolower()}},@{n="RecordData";e={$_.addresses.$AdapterName.addr}} | sort RecordData

    switch($DNSProvider){
        CloudServer{
            if(!(Get-WindowsFeature DNS).Installed){Write-Verbose "The DNS Role is not installed.";Return $false}
            elseif((Get-DnsServerZone $ZoneName -ErrorAction SilentlyContinue) -eq $null){Write-Verbose "The zone $($ZoneName) does not exist";Return $false}
            else{
                $localRecords = GetLocalRecords -ZoneName $ZoneName
                if($localRecords.Count -eq 0){Write-Verbose "Local Zone $($ZoneName) contains no records."; Return $false}

                $cloudArray = CompareRecords -records $localRecords -foreignRecords $cloudRecords
                $localArray = CompareRecords -records $cloudRecords -foreignRecords $localRecords
                
                if(($cloudArray.count -gt 0) -or ($localArray.count -gt 0)){Write-Verbose "One or more DNS records are out of Sync"; Return $false}
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

    $cloudRecords = Get-rsCloudServersInfo | ? status -eq "ACTIVE" | select @{n="name";e={$_.name.tolower()}},@{n="RecordData";e={$_.addresses.$AdapterName.addr}} | sort RecordData

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

            $localRecords = GetLocalRecords -ZoneName $ZoneName
            $cloudArray = CompareRecords -records $localRecords -foreignRecords $cloudRecords
            if($localRecords.count -gt 0){
                $localArray = CompareRecords -records $cloudRecords -foreignRecords $localRecords
            }
            if($cloudArray.count -gt 0){
                foreach($record in $cloudArray){
                    SyncRecords -SyncDirection SyncToLocal -HostName $record.name -RecordData $record.RecordData -ZoneName $ZoneName
                }
            }
            elseif($localArray.count -gt 0){
                foreach($record in $localArray){
                    SyncRecords -SyncDirection SyncToCloud -HostName $record.name -RecordData $record.RecordData -ZoneName $ZoneName
                }
            }
        }
        CloudDNS{

        }
    }
}