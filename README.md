```Posh
rsDNSSync SyncZone{
  ZoneName = "<Domain Name>"
  AdapterName = "<Name of the NIC Adapter to gather IP Addresses from {Public, ServiceNet, Other}>"
  DNSProvider = "<Who will host the DNS Zone. Options are CloudServer or CloudDNS>"
}
```

## v2.0.0
New Release with improved code. This release also includes the option to add custom Records to a separate zone.

```Posh
rsDNSCustomRecord ConfigRecord{
	ZoneName = "example.com"
	Ensure = "Present"
	DNSProvider = "CloudServer"
	HostName = "test"
	RecordType = "A"
	RecordData = "192.168.1.1"
}
```

You can also add CNAME & MX records using this module.

Requirements/Dependencies:
- Windows Server 2012 R2
- rsCommon module

Known Issues/To Do:
- Current implementation will clear out custom Records. Needs module to create and modify a custom zone.
- CloudDNS functionality has not been implemented yet. That is on a to do list once I have time to delve into the API.
