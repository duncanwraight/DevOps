# Specify Azure CLI as the authentication method
provider "azurerm" {
  version = "=1.21.0"
  subscription_id = "${local.subscription}"
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
    DT    = ""
    PPT   = ""
    PR    = ""
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

  prefix_group      = "${var.project}-${var.environment}"
  prefix_specific   = "${var.project}-##TYPE##-${var.environment}"
  prefix_alpha      = "${format("%.6s", var.project)}##TYPE##${var.environment}"
  prefix_lower      = "${lower(local.prefix_alpha)}"
  name_sacc         = "${lower(format("%.6s", var.project))}${lower(var.environment)}sa" 
  #storage_account_base_uri = "${azurerm_storage_account.main.primary_blob_endpoint}${azurerm_storage_container.disks.name}"
}
