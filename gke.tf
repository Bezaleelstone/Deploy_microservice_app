# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0



# GKE cluster
data "google_container_engine_versions" "gke_version" {
  location = var.zone
}

resource "google_container_cluster" "cluster" {
  name     = "capstone-gke"
  location = var.zone

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.vpc.id
  subnetwork = google_compute_subnetwork.subnet.id
}

# Separately Managed Node Pool
resource "google_container_node_pool" "primary_nodes" {
  name       = google_container_cluster.cluster.name
  location   = var.zone
  cluster    = google_container_cluster.cluster.name
  
  version = data.google_container_engine_versions.gke_version.release_channel_latest_version["STABLE"]
  node_count = 2

  autoscaling {
    min_node_count = 1
    max_node_count = 5
  }
  
  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]

    labels = {
      env = var.project_id
    }

    # preemptible  = true
    machine_type = "e2-medium"
    tags         = ["gke-node", "${var.project_id}-gke"]
    metadata = {
      disable-legacy-endpoints = "true"
    }
    disk_type = "pd-standard"  # Change this from "pd-ssd" to "pd-standard"
    disk_size_gb = 100
    
  }
}

resource "google_compute_firewall" "nodeport_firewall" {
  name    = "allow-nodeport"
  project = var.project_id
  network = google_compute_network.vpc.id

  allow {
    protocol = "tcp"
    ports    = ["30001"]
  }

  source_ranges = ["0.0.0.0/0"]  # Allow traffic from any IP. Adjust this as needed for security.

  target_tags = ["gke-node",  "${var.project_id}-gke"]  # Ensure this matches the tags applied to your GKE nodes
}
# # Kubernetes provider
# # The Terraform Kubernetes Provider configuration below is used as a learning reference only. 
# # It references the variables and resources provisioned in this file. 
# # We recommend you put this in another file -- so you can have a more modular configuration.
# # https://learn.hashicorp.com/terraform/kubernetes/provision-gke-cluster#optional-configure-terraform-kubernetes-provider
# # To learn how to schedule deployments and services using the provider, go here: https://learn.hashicorp.com/tutorials/terraform/kubernetes-provider.

# provider "kubernetes" {
#   load_config_file = "false"

#   host     = google_container_cluster.primary.endpoint
#   username = var.gke_username
#   password = var.gke_password

#   client_certificate     = google_container_cluster.primary.master_auth.0.client_certificate
#   client_key             = google_container_cluster.primary.master_auth.0.client_key
#   cluster_ca_certificate = google_container_cluster.primary.master_auth.0.cluster_ca_certificate
# }
