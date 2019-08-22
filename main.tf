provider "google" {
  credentials = "${file(var.gloud_creds_file)}"
  project     = "${var.project_name}"
  region      = "${var.location}"
}

resource "google_container_cluster" "primary" {
  name        = "${var.cluster_name}"
  project     = "${var.project_name}"
  description = "Demo GKE Cluster"
  location    = "${var.location}-b"
  min_master_version = "${var.kubernetes_ver}"

  remove_default_node_pool = true
  initial_node_count = 1

  master_auth {
    username = "${random_id.username.hex}"
    password = "${random_id.password.hex}"
  }
}

resource "google_container_node_pool" "primary" {
  name       = "${var.cluster_name}-node-pool"
  project     = "${var.project_name}"
  location   = "${var.location}-b"
  cluster    = "${google_container_cluster.primary.name}"
  node_count = 2

  node_config {
    preemptible  = true
    machine_type = "${var.machine_type}"

    metadata = {
      disable-legacy-endpoints = "true"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/compute",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }
}


provider "kubernetes" {
  host = "https://${google_container_cluster.primary.endpoint}"
  cluster_ca_certificate = "${base64decode(google_container_cluster.primary.master_auth.0.cluster_ca_certificate)}"
  username = "${random_id.username.hex}"
  password = "${random_id.password.hex}"
  
}

data "template_file" "kubeconfig" {
  template = file("kubeconfig-template.yaml")

  vars = {
    cluster_name    = google_container_cluster.primary.name
    user_name       = google_container_cluster.primary.master_auth[0].username
    user_password   = google_container_cluster.primary.master_auth[0].password
    endpoint        = google_container_cluster.primary.endpoint
    cluster_ca      = google_container_cluster.primary.master_auth[0].cluster_ca_certificate
    client_cert     = google_container_cluster.primary.master_auth[0].client_certificate
    client_cert_key = google_container_cluster.primary.master_auth[0].client_key
  }
}

resource "local_file" "kubeconfig" {
  content  = data.template_file.kubeconfig.rendered
  filename = "kubeconfig"
}

resource "kubernetes_namespace" "prod" {
  metadata {
    name = "prod"
  }
  depends_on = ["google_container_node_pool.primary"]
}

resource "kubernetes_namespace" "dev" {
  metadata {
    name = "dev"
  }
  depends_on = ["google_container_node_pool.primary"]
}

resource "kubernetes_namespace" "jenkins" {
  metadata {
    name = "jenkins"
  }
  depends_on = ["google_container_node_pool.primary"]
}

resource "kubernetes_secret" "credentials" {
  metadata {
    name = "scredentials"
    namespace = "jenkins" 
  }

  data = {
    "credentials.xml" = "${file("${path.module}./credentials-jenk/credentials.xml")}"
  }
  depends_on = ["kubernetes_namespace.jenkins"]
}

resource "kubernetes_secret" "jenkins-gcr-json" {
  metadata {
    name = "jenkins-gcr-json"
    namespace = "jenkins"
  }

  data = {
    "jenkins-gcr.json" = "${file("${var.storage_creds_file}")}"
  }
  depends_on = ["kubernetes_namespace.jenkins"]
}

resource "null_resource" "configure_tiller_jenkins" {
  provisioner "local-exec" {
    command = <<LOCAL_EXEC
kubectl --namespace=jenkins --kubeconfig=kubeconfig create secret generic secrets --from-file=${path.module}./credentials-jenk/secrets/master.key  --from-file=${path.module}./credentials-jenk/secrets/hudson.util.Secret
kubectl config use-context ${var.cluster_name} --kubeconfig=${local_file.kubeconfig.filename}
kubectl apply -f create-helm-service-account.yml --kubeconfig=${local_file.kubeconfig.filename}
kubectl apply -f create-jenkins-service-account.yml --kubeconfig=${local_file.kubeconfig.filename}
helm init --service-account helm --upgrade --wait --kubeconfig=${local_file.kubeconfig.filename}
helm install --name jenkins --namespace jenkins -f jenkins-chart.yaml stable/jenkins --wait --kubeconfig=${local_file.kubeconfig.filename}
LOCAL_EXEC
  }
  depends_on = ["google_container_node_pool.primary","local_file.kubeconfig","kubernetes_namespace.jenkins"]
}
