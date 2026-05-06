#
# Variables Configuration. Check for REPLACE to substitute custom values. Check the description of each
# tag for more information
#

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  default = "eks-dev" #REPLACE
}

variable "vpc_cidr_block" {
  description = "CIDR block"
  default = "192.168.0.0/16"
}


variable "network_availability_zones" {
  description = "Configure availability zones configuration for VPC. Leave as default for India. Recommendation is to have subnets in at least two availability zones"
  default = ["ap-south-1b", "ap-south-1a"] #REPLACE IF NEEDED
}

variable "availability_zones" {
  description = "Amazon EKS runs and scales the Kubernetes control plane across multiple AWS Availability Zones to ensure high availability. Specify a comma separated list to have a cluster spanning multiple zones. Note that this will have cost implications"
  default = ["ap-south-1b"] #REPLACE IF NEEDED
}

variable "kubernetes_version" {
  description = "kubernetes version"
  default = "1.28"
}

variable "instance_type" {
  description = "eGov recommended below instance type as a default"
  default = "r5ad.large"
}

variable "override_instance_types" {
  description = "Arry of instance types for SPOT instances"
  default = ["r5a.large", "r5ad.large", "r5d.large", "m4.xlarge"]

}

variable "number_of_worker_nodes" {
  description = "eGov recommended below worker node counts as default"
  default = "3" #REPLACE IF NEEDED
}

variable "ssh_key_name" {
  description = "ssh key name, not required if your using spot instance types"
  default = "pucar-ssh-dev" #REPLACE
}


variable "db_name" {
  description = "RDS DB name. Make sure there are no hyphens or other special characters in the DB name. Else, DB creation will fail"
  default = "rdsdev" #REPLACE
}

variable "db_username" {
  description = "RDS database user name"
  default = "pucar_rds_dev" #REPLACE
}

#DO NOT fill in here. This will be asked at runtime
variable "db_password" {}

variable "public_key" {
  default = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDN3pt9+DOt9kIr3XtF/e+4b1XgfcwtgTCKDDYflB5VeXVeVKe+6tR4b+XWKXi6SlDnp/aec0mbTbVPo5Lns9xImtrFEbXg5GONrFvy7vhbxj5pts0kvGS4FsBOt+z6i/Ws6HHrctKOP+V223Gv6+eqLjZTzG1G8SGp+y3viJ2UFrTCiDTjwqy0+AU9Hqou0ycXIlWXoISnyKY9kpDY2i1UtstJ10e9L3IBEjZsdU4qQ/zmDzYBtj9aGI4z04K0Y0TLV6CZCzzHzNHzg2XO6v1OiFEfnTXhFj8EjWDawflSROv/eRPz+pPcwJ0U24SkPH1Qg+rL+TDQ6DJPPK7tzqPgA7FCK0qY22lp2LdGUtAnAmWJeF4J9xzOtBDF2hacDlXwnEH7Zkzmt5Be8k7lJosIX27+P3bn4Rp52DV/9YYG2YzYPbUhv/8nbyHCID+O4RhBq/jWCBJzqiD0mUzAgMwjkrBmgAvQXaTlRr7o2qhHt8aInx1Xm6oUqdbNkjf94eM= beehyv@bhcp0179"
  description = "ssh key"
}

## change ssh key_name eg. digit-quickstart_your-name



