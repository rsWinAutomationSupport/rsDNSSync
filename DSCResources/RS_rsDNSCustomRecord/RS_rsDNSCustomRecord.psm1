function LocateRecord{
    param(
        $ZoneName,
        $recordName,
        $recordType,
        $recordData
    )
    
    $record = Get-DnsServerResourceRecord -Name $recordName -RRType $recordType -ZoneName $ZoneName
    if($record -eq $null){Write-Verbose "No record found matching $($HostName)";Return $false}
    switch($recordType){
        A{
            $recordIP = $record.RecordData.IPv4Address.IPAddressToString
            if($RecordData -ne $recordIP){Write-Verbose "The record data found for $($HostName) does not match user supplied values";Return $false}
            else{Write-Verbose "Record data found for $($HostName) matches user supplied values";Return $true}
        }
        CName{
            $recordAlias = $record.RecordData.HostNameAlias
            if($RecordData -ne $recordAlias){Write-Verbose "The record data found for $($HostName) does not match user supplied values";Return $false}
            else{Write-Verbose "Record data found for $($HostName) matches user supplied values";Return $true}
        }
        Mx{
            $recordMx = $record.RecordData.MailExchange
            if($RecordData -ne $recordMx){Write-Verbose "The record data found for $($HostName) does not match user supplied values";Return $false}
            else{Write-Verbose "Record data found for $($HostName) matches user supplied values";Return $true}
        }
    }
}
function AddRecord{
    param(
        $ZoneName,
        $recordName,
        $recordType,
        $recordData
    )

    switch($recordType){
        A{
            Add-DnsServerResourceRecordA -Name $recordName -IPv4Address $recordData -ZoneName $ZoneName -Verbose
        }
        CName{
            Add-DnsServerResourceRecordCName -Name $HostName -HostNameAlias $recordData -ZoneName $ZoneName -Verbose
        }
        Mx{
            Add-DnsServerResourceRecordMX -Name $HostName -MailExchange $recordData -ZoneName $ZoneName -Verbose
        }
    }
}
function RemoveRecord{
    param(
        $ZoneName,
        $recordName,
        $recordType,
        $recordData
    )

    Remove-DnsServerResourceRecord -Name $recordName -RecordData $recordData -RRType $recordType -ZoneName $ZoneName -Force -Verbose
}
function Get-TargetResource{
    [OutputType([hashtable])]
    param(
        [ValidateSet("Present","Absent")]
        $Ensure = "Present",
        [ValidateSet("CloudServer","CloudDNS")]
        $DNSProvider = "CloudServer",
        [Parameter(Mandatory = $true)]
        $ZoneName,        
        [Parameter(Mandatory = $true)]
        $HostName,
        [Parameter(Mandatory = $true)]
        [ValidateSet("A","CNAME","Mx")]
        $RecordType,
        [Parameter(Mandatory = $true)]
        $RecordData
    )

    @{
        "Ensure" = $Ensure
        "DNSProvider" = $DNSProvider
        "ZoneName" = $ZoneName
        "HostName" = $HostName
        "RecordType" = $RecordType
        "RecordData" = $RecordData
    }
}
function Test-TargetResource{
    param(
        [ValidateSet("Present","Absent")]
        $Ensure = "Present",
        [ValidateSet("CloudServer","CloudDNS")]
        $DNSProvider = "CloudServer",
        [Parameter(Mandatory = $true)]
        $ZoneName,
        [Parameter(Mandatory = $true)]
        $HostName,
        [Parameter(Mandatory = $true)]
        [ValidateSet("A","CNAME","Mx")]
        $RecordType,
        [Parameter(Mandatory = $true)]
        $RecordData
    )

    switch($DNSProvider){
        CloudServer{
            if(!(Get-WindowsFeature DNS).Installed){Return $false}
            elseif((Get-DnsServerZone $ZoneName -ErrorAction SilentlyContinue) -eq $null){Return $false}
            else{
                $recordState = LocateRecord -ZoneName $ZoneName -recordName $HostName -recordType $RecordType -recordData $RecordData
                switch($Ensure){
                    Present{
                        if(!($recordState)){Write-Verbose "DSC Config requires record $($HostName) and could not locate record.";Return $false}
                    }
                    Absent{
                        if($recordState){Write-Verbose "DSC Config does not require record $($HostName) however record is present.";Return $false}
                    }
                }
            }
        }
        CloudDNS{

        }
    }
}
function Set-TargetResource{
    param(
        [ValidateSet("Present","Absent")]
        $Ensure = "Present",
        [ValidateSet("CloudServer","CloudDNS")]
        $DNSProvider = "CloudServer",
        [Parameter(Mandatory = $true)]
        $ZoneName,
        [Parameter(Mandatory = $true)]
        $HostName,
        [Parameter(Mandatory = $true)]
        [ValidateSet("A","CNAME","Mx","Ptr")]
        $RecordType,
        [Parameter(Mandatory = $true)]
        $RecordData
    )

    switch($DNSProvider){
        CloudServer{
            if(!(Get-WindowsFeature DNS).Installed){Return $false}
            elseif((Get-DnsServerZone $ZoneName -ErrorAction SilentlyContinue) -eq $null){Return $false}
            else{
                $recordState = LocateRecord -ZoneName $ZoneName -recordName $HostName -recordType $RecordType -recordData $RecordData
                switch($Ensure){
                    Present{
                        if(!($recordState)){
                            AddRecord -ZoneName $ZoneName -recordName $HostName -recordType $RecordType -recordData $RecordData
                        }
                    }
                    Absent{
                        if($recordState){
                            RemoveRecord -ZoneName $ZoneName -recordName $HostName -recordType $RecordType -recordData $RecordData
                        }
                    }
                }
            }
        }
        CloudDNS{

        }
    }
}