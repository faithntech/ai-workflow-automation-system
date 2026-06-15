variable "aws_region" {
  type = string
}

variable "ami_id" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "key_name" {
  type = string
}

variable "my_ip" {
  type = string
}

variable "domain_name" {
  description = "n8n domain"
  type        = string
  default     = "n8n.shielacloudevops.work"
}
