terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.2.0"
    }
  }
}

resource "kubernetes_service" "example" {
  metadata {
    name = "terraform-example"
    annotations = {
      "load-balancer.hetzner.cloud/location" = "hel1"
    }
  }
  spec {
    selector = {
      app = kubernetes_pod.example.metadata.0.labels.app
    }
    session_affinity = "ClientIP"
    port {
      port        = 80
      target_port = 80
    }

    type = "LoadBalancer"
  }

  wait_for_load_balancer = true
}

resource "kubernetes_pod" "example" {
  metadata {
    name = "terraform-example"
    labels = {
      app = "test"
    }
  }

  spec {
    container {
      image = "nginx:latest"
      name  = "example"
    }
  }
}

output "load_balancer_address" {
  value = kubernetes_service.example.status[0].load_balancer[0].ingress
}