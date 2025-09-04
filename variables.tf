variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "ssh_cidr" {
  description = "CIDR block allowed to SSH (default: your public IP only)"
  type        = string
  default     = null
}
