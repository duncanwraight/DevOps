# Specify Azure CLI as the authentication method
provider "azurerm" {
  version = "=1.21.0"
  subscription_id = "${local.subscription}"
}

variable "num_VMs" {
  description = "How many VMs should be created?"
}

variable "purpose" {
  description = "What is this infrastructure going to be used for, e.g. Testing or Live Infrastructure"
}

variable "project" {
  description = "Project or name for the virtual machine, e.g. Kubernetes or ELK-Cluster"
}

variable "environment" {
  description = "Environment that the resource will be stored in, e.g. PPT"
}

variable "expiry_date" {
  description = "When can this resource be deleted? Write \"Permanent\" for long-lasting resources"
}

variable "kubespray_path" {
  description = "Full local machine path to kubespray installation"
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

  prefix            = "DEVOPS-TEST-KUBERNETES-HA"
  prefix_formatted  = "devopstestk8sha"
}
