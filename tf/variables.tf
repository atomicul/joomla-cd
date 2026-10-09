variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "name" {
  type    = string
  default = "joomla-cd"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "instances" {
  description = "Instances to create, mapped to the comma-separated Role tag consumed by the Ansible inventory."
  type        = map(string)
  default = {
    source = "web,db"
    target = "web,db"
  }
}

variable "ssh_public_key" {
  description = "Public key material (e.g. contents of ~/.ssh/id_ed25519.pub) installed for ec2-user."
  type        = string
}

variable "ssh_allowed_cidr" {
  description = "CIDR allowed to reach port 22."
  type        = string
  default     = "0.0.0.0/0"
}
