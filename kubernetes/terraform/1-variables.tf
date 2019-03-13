# Specify Azure CLI as the authentication method
provider "azurerm" {
  version = "=1.21.0"
  subscription_id = "${local.subscription}"
}

variable "organisation" {
  description = "What is the name of your organisation, e.g. Tombola"
}

variable "purpose" {
  description = "What is this infrastructure going to be used for, e.g. Testing or Live Infrastructure"
}

variable "project" {
  description = "Project or name for the virtual machine, e.g. Kubernetes or ELK-Cluster"
}

variable "type" {
  type = "list"

  description = "Specific types of VM, e.g. Master/Slave-1/Slave-2 or Logstash/Kibana"
}

variable "environment" {
  description = "Environment that the resource will be stored in, e.g. PPT"
}

variable "expiry_date" {
  description = "When can this resource be deleted? Write \"Permanent\" for long-lasting resources"
}

locals {

  subscriptions = {
    DT    = "9f5f1382-1bd7-4108-8d48-a65a9ea648a7"
    PPT   = "7f695720-f2c9-4dc0-9ef1-b6ac8e3eb6b3"
    PR    = "76fb2915-02f1-410b-b4b5-fb42d75ae91c"
  }

  subscription = "${lookup(local.subscriptions, var.environment)}"

  tags = {
    Project = "${var.project}"
    Purpose = "${var.purpose}"
    Expiry_Date = "${var.expiry_date}"
    Environment_Name = "${upper(var.environment)}"
    Resource_Owner = "Duncan Wraight"
  }

  count_of_types = "${length(var.type)}"

  prefix_group      = "${var.organisation}-${var.project}-${var.environment}"
  prefix_specific   = "${var.organisation}-${var.project}-##TYPE##-${var.environment}"
  prefix_alpha      = "${var.organisation}${format("%.6s", var.project)}##TYPE##${var.environment}"
  prefix_lower      = "${lower(local.prefix_alpha)}"
  name_sacc         = "${lower(format("%.6s", var.project))}${lower(var.environment)}sa" 
  #storage_account_base_uri = "${azurerm_storage_account.main.primary_blob_endpoint}${azurerm_storage_container.disks.name}"
}
