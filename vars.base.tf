
variable "project" {}

variable "root_key_public_path" { default = "../files/awsroot.pub" }
#variable "root_key_private_path" { type = string }

variable "aws_cli_profile" { }

variable "certificates_path" { default = "../certificates"}
variable "certificates_default_chain" { default = "GEANT_OV_RSA_CA_4" }





variable "subnet_ids_by_az" {}
variable "vpc_id" {}
variable "vpc_cidr" {}
variable "backup_tags" {}

