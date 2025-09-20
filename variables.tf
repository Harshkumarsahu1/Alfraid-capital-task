variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "asia-south1"
}

variable "zone" {
  description = "GCP zone"
  type        = string
  default     = "asia-south1-a"
}

variable "network_cidr" {
  description = "CIDR for the VPC primary range"
  type        = string
  default     = "10.10.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR for the subnet"
  type        = string
  default     = "10.10.10.0/24"
}

variable "server_machine_type" {
  description = "Machine type for Nomad server"
  type        = string
  default     = "e2-small" # lower-cost default
}

variable "client_machine_type" {
  description = "Machine type for Nomad clients"
  type        = string
  default     = "e2-micro" # lowest-cost option; for demos only
}

variable "client_count" {
  description = "Number of Nomad client instances"
  type        = number
  default     = 1
}

variable "labels" {
  description = "Resource labels"
  type        = map(string)
  default     = {
    project = "nomad-gcp"
  }
}

variable "client_preemptible" {
  description = "Use preemptible (spot) instances for Nomad clients to reduce cost"
  type        = bool
  default     = true
}
