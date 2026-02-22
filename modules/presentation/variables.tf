variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnets" {
  type = list(string)
}

variable "domain_name" {
  description = "The root domain name registered in Route 53"
  type        = string
}