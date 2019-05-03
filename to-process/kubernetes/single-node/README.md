# Kubernetes cluster deployment using Terraform and Ansible

## Terraform
 - Populate the Terraform variables file (`terraform/1-variables.tf`)
 - From the `terraform` directory, run the command `terraform apply`

## Bash script to populate Ansible inventory
 - Using the "Public IPs" output from Terraform, run the following command: `bash add-pips-to-ssh.sh <<ip1>> <<ip2>>`
 - This a) adds the relevant IPs to the Ansible inventory and b) adds these hosts as "known hosts" so Ansible can SSH to them immediately

## Ansible playbook
 - Navigate to the `ansible` directory
 - Run the command `ansible-playbook ans-master-deployment.yml -i ans-inventory.yml --extra-vars="kuserpassword=Homegroup1! kuserpassword_salt=Test"`

## Destroying the infrastructure
 - Navigate to the `terraform` directory
 - Run the command `terraform destroy`
