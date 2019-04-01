# Kubernetes HA cluster creation

## Introduction

This set of scripts has been written to create a highly-available Kubernetes cluster using Kubespray (version 2.8.3).

## Usage

 - Run the Terraform scripts; this will create the necessary infrastructure in Azure then spit out an Ansible Playbook run command
 - This Playbook is the Kubespray deployment script which will create all of the necessary configuration for the HA Kubernetes cluster
