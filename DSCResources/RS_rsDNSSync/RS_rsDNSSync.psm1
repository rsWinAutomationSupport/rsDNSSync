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
    if(($localRecords -eq $null) -or ($localRecords.count -eq 0)){Return $null}
    else{Return $localRecords}
}
function CompareRecords{
    param(
        $sourceRecords,
        $targetRecords
    )

    $recordArray = $targetRecords

    foreach($record in $sourceRecords){
        if(($targetRecords.name.Contains($record.name)) -and ($targetRecords.RecordData.Contains($record.RecordData))){
            Write-Verbose "Target match found for $($record.name): $($record.RecordData)"
            $recordArray = $recordArray | ?{$_ -notmatch $record}
        }
        else{
            Write-Verbose "Target match not found for $($record.name): $($record.RecordData)"
        }
    }
    if(($recordArray -eq $null) -or ($recordArray.count -eq 0)){Return $null}
    else{Return $recordArray}
}
function SyncRecords{
    param(
        [ValidateSet("AddtoServer","RemovefromServer")]
        $SyncTask,
        $HostName,
        $RecordData,
        $ZoneName
    )

    switch($SyncTask){
        AddtoServer{
            Add-DnsServerResourceRecord -ZoneName $ZoneName -A -Name $HostName -IPv4Address $RecordData -Verbose
        }
        RemovefromServer{
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

    $DNSProvider = (Get-WindowsFeature DNS).InstallState
    $ZoneName = (Get-DnsServerZone $ZoneName -ErrorAction SilentlyContinue).ZoneFile
    $AdapterName = (Get-NetAdapter -InterfaceAlias $AdapterName).Status

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
                if($localRecords -eq $null){Write-Verbose "Local Zone $($ZoneName) contains no records."; Return $false}

                Write-Verbose "Comparing cloud records to local records"
                $cloudArray = CompareRecords -sourceRecords $localRecords -targetRecords $cloudRecords
                Write-Verbose "Comparing local records to cloud records"
                $localArray = CompareRecords -sourceRecords $cloudRecords -targetRecords $localRecords
                
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
            $cloudArray = CompareRecords -sourceRecords $localRecords -targetRecords $cloudRecords
            if($localRecords -ne $null){
                $localArray = CompareRecords -sourceRecords $cloudRecords -targetRecords $localRecords
            }
            else{$localArray = $null}
            if($cloudArray -ne $null){
                foreach($record in $cloudArray){
                    SyncRecords -SyncTask AddtoServer -HostName $record.name -RecordData $record.RecordData -ZoneName $ZoneName
                }
            }
            elseif($localArray -ne $null){
                foreach($record in $localArray){
                    SyncRecords -SyncTask RemovefromServer -HostName $record.name -RecordData $record.RecordData -ZoneName $ZoneName
                }
            }
        }
        CloudDNS{

        }
    }
}