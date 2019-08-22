variable "cluster_name" {
  default = "gke-gevops055"
}
variable "project_name" {
  default = "absolute-router-242207"
}

variable "gloud_creds_file" {
  default = "~/.kube/account.json"
}

variable "storage_creds_file" {
  default = "/root/.kube/account.json"
}

variable "location" {
  default = "europe-west1"
}

variable "machine_type" {
//  default = "g1-small"
  default = "n1-standard-1"
}

// Database configuration
variable "database_instance_name" {
  default = "main-postgres"
}

variable "database_prod_user_pass" {
  default = "8c7yoI66pd"
}

variable "database_test_user_pass" {
  default = "8c7yoI66pd"
}

variable "kubernetes_ver" {
  default = "1.11"
}

resource "random_id" "username" {
  byte_length = 14
}

resource "random_id" "password" {
  byte_length = 16
}

