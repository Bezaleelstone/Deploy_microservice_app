variable "project_id" {
  description = "project id"
}

variable "region" {
  description = "region"
}


variable "zone" {
  description = "zone"
}

variable "bucket_name" {
  description = "The name of the GCS bucket for storing Terraform state."
  type        = string
}

variable "gke_username" {
  default     = ""
  description = "gke username"
}

variable "gke_password" {
  default     = ""
  description = "gke password"
}

variable "gke_num_nodes" {
  default     = 1
  description = "number of gke nodes"
}