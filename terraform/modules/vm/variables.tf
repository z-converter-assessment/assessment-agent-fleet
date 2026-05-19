variable "name" {
  type = string
}

variable "image" {
  type = string
}

variable "flavor" {
  type = string
}

variable "role" {
  type = string
}

variable "keypair" {
  type = string
}

variable "network_id" {
  type = string
}

variable "environment" {
  type = string
}

variable "metadata" {
  type    = map(string)
  default = {}
}
