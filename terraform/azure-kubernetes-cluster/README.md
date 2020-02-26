# Azure VM creation script

This Terraform script will create a "cluster" of VMs.

Provide a list of "types" (e.g. Master/Slave,
ElasticMaster/ElasticData1/ElasticData2/Logstash/Kibana or even just Agent1/Agent2/Agent3 etc).

The script will put all of the resources in the same Resource Group, sharing the same Storage
Container Account and other resources, but creating separate VMs each with their own Public IP
Address.
