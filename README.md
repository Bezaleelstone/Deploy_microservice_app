# Automating the Deployment of Socks Shop Microservices application on Kubernetes Using Infrastructure as Code (IaaC)

**Overview:** 

A microservices-based architecture application is deployed on Kubernetes and there’s a need to create a clear IaaC (Infrastructure as Code) deployment to be able to deploy the services in a fast manner.
 
**Setup Details:**

Provision the Socks Shop example microservice application - 
* https://github.com/microservices-demo/microservices-demo.github.io
* https://github.com/microservices-demo/microservices-demo/tree/master

**Task Instructions:**
1. All deliverables need to be deployed using an Infrastructure as Code approach.
2. In your solution please emphasize readability and maintainability (make yor application deployment clear)
3. We expect a clear way to recreate your setup and will evaluate the project decisions based on:
* Deploy pipeline
* Metrics (Alertmanager)
* Monitoring (Grafana)
* Logging (Prometheus)
5. Use Prometheus as a monitoring tool
6. Use Ansible or Terraform as the configuration management tool.
7. You can use an IaaS provider of your choice.
8. The application should run on Kubernetes

**Extra Project Requirements:**
* The application should run on HTTPS with a Let’s Encrypt certificate
* Bonus points for securing the infrastructure with network perimeter security access rules
* Bonus points if you use Ansible Vault for encrypting sensitive information

## INTRODUCTION
This guide demonstrates how to deploy the Socks Shop microservices application on Kubernetes using Infrastructure as Code (IaaC). We will leverage Terraform for infrastructure provisioning, Kubernetes manifests for deploying the services and Git actions for the CI/CD pipeline. Additionally, we'll set up Prometheus and Grafana for monitoring, Alertmanager for alerts, Ingress for routing, and Let's Encrypt for HTTPS certificates.

By the end of this guide, you will have a fully automated, secure, and monitored deployment of the Socks Shop app on Google Kubernetes Engine (GKE).

**Prerequisites:**
* Basic knowledge of Linux command line
* Google Cloud SDK installed and configured. 
* Terraform installed.
* kubectl CLI installed.
* Helm CLI installed.
* A GitHub account for cloning the repository.

## Step 1: Provisioning the Kubernetes Cluster with Terraform

We begin by writing a Terraform configuration to create a VPC, with a subnet attached and a GKE cluster. This cluster will be assigned to this subnet. It is advisable to isolate your cluster.

1. Create a Terraform configuration file (main.tf) with the following content:

```
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
```
2. Here we will need to create a VPC and subnet for the cluster. Create a Terraform configuration file (vpc.tf) with the following content:

```
provider "google" {
  project = var.project_id
  region  = var.region
}

# VPC
resource "google_compute_network" "vpc" {
  name                    = "capstone-vpc"
  auto_create_subnetworks = "false"
}

# Subnet
resource "google_compute_subnetwork" "subnet" {
  name          = "subnet1"
  region        = var.region
  network       = google_compute_network.vpc.id
  ip_cidr_range = "10.10.0.0/24"
}
```
3. Initialize and Apply the Terraform configuration:

```
terraform init
terraform apply --auto-approve
```
## Step 2: Connecting the Cluster to kubectl

Once the cluster is provisioned, connect it to kubectl using:
```
gcloud container clusters get-credentials <cluster_name> --zone <zone> --project <project_id>
```
## Step 3: Deploying the Socks Shop Microservices

1. Clone the Socks Shop repository  and change directory to the where the deployment manifest is located:

```
git clone https://github.com/microservices-demo/microservices-demo
cd microservices-demo/deploy/kubernetes
```
2. Create a namespace for the application and deploy the services:
```
kubectl create namespace sock-shop
kubectl apply -f complete-demo.yaml
kubectl config set-context --current --namespace=sock-shop
```

## Step 4: Deploying Prometheus and Grafana for Monitoring
In the root folder of the repository, apply the monitoring manifests:

```
cd /capston_gke_cluster/microservices-demo
kubectl apply -f ./deploy/kubernetes/manifests-monitoring
```
This will deploy Prometheus and Grafana, which can be used for collecting metrics and visualizing them.

## Step 5: Installing Ingress Controller
Ingress Controller is an important component that manages access to services within a Kubernetes cluster by providing externally accessible URLs. 

Install an Nginx ingress controller using Helm:

```
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install nginx-ingress ingress-nginx/ingress-nginx --namespace ingress-nginx --create-namespace
```

## Step 6: Installing Certificate Manger
Cert-Manager automates the management, issuance, and renewal of TLS/SSL certificates in a Kubernetes cluster. This ensures that your application and services can communicate securely using HTTPS.

Install Cert-Manager for automatic certificate management:

```
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --version v1.5.4 --set installCRDs=true
```

## Step 7: Configuring Ingress controller and HTTPS with Let's Encrypt

We will create configuration files for the ingress controller (ingress.yaml) and cluster issuer (cluster-issuer.yaml). `ingress.yaml` will specify the services that are to be exposed to a defined host through a loadbalance. `cluster-issuer.yaml` specifies how Cert-Manager should obtain and manage TLS/SSL certificates for the entire cluster.

ingress.yaml
```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: sockshop
  namespace: sock-shop
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-production"
    nginx.ingress.kubernetes.io/rewrite-target: /
    kubernetes.io/ingress.class: nginx
spec:
  ingressClassName: nginx
  rules:
    - host: sock.praisenwanguma.me
      http:
        paths:
          - pathType: Prefix
            backend:
              service:
                name: front-end
                port:
                  number: 80
            path: /
```

cluster-issuer.yaml
```
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-production
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: bezaleel.nwanguma@gmail.com
    privateKeySecretRef:
      name: letsencrypt-production
    solvers:
    - http01:
        ingress:
          class: nginx
```
Next, apply the ClusterIssuer and Ingress manifests to enable HTTPS:
```
kubectl apply -f cluster-issuer.yaml
kubectl apply -f ingress.yaml
```

## Step 8: Setting Up Alerting with Alertmanager

1. To receive alerts on Slack when an issue occurs, such as a pod failure, create a secret with your Slack webhook URL:

```
kubectl create secret generic slack-hook-url --from-literal=slack-hook-url='https://hooks.slack.com/services/your/slack/webhook' -n sock-shop
```
For more information see
https://api.slack.com/incoming-webhooks

2. We will define rules in the `prometheus-alertrules.yaml` file which has been configured to communicate wih Alert Manager:

Edit the `05-prometheus-alertrules.yaml` file
```
nano ./deploy/kubernetes/manifests-alerting/05-prometheus-alertrules.yaml
```
Populate the file with these contents:
```
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-alertrules
  namespace: monitoring
data:
  alert.rules: |-
    groups:
    - name: HighErrorRate
      rules:
      - alert: HighErrorRate
        expr: rate(request_duration_seconds_count{status_code="500"}[5m]) > 1
        for: 5m
        labels:
          severity: slack
        annotations:
          summary: "High HTTP 500 error rates"
          description: "Rate of HTTP 500 errors per 5 minutes: {{ $value }}"
    - name: KubernetesPods
      rules:
      - alert: PodDown
        expr: kube_pod_status_phase{phase!="Running"} > 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Pod {{ $labels.pod }} is down"
          description: "Pod {{ $labels.pod }} in namespace {{ $labels.namespace }} is down on {{ $labels.node }}."
```

Then, create the Alertmanager configuration:
```
kubectl create -f ./deploy/kubernetes/manifests-alerting
```
## Step 9: Adding Network Policies for Security
To set up network perimeter security rules for additional protection. We will apply the configuration file in the manifest_policy directory. This contains manifests that declares network policy rules.
```
kubectl apply -f ./deploy/kubernetes/manifests-policy
```
## Step 10: CI/CD pipeline using Git Actions






