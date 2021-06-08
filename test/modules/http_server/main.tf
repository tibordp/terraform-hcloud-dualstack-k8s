terraform {
  required_providers {
    kubernetes-alpha = {
      source  = "hashicorp/kubernetes-alpha"
      version = "0.4.1"
    }
  }
}

resource "kubernetes_manifest" "nginx-service" {
  manifest = {
    "apiVersion" = "v1"
    "kind"       = "Service"
    "metadata" = {
      "name" = "nginx-service"
      "annotations" = {
        "load-balancer.hetzner.cloud/location" = "hel1"
        "load-balancer.hetzner.cloud/hostname" = "example.com"
      }
    }
    "spec" = {
      "ipFamilyPolicy" = "PreferDualStack"
      "ports" = [
        {
          "port"       = 80
          "targetPort" = 80
        },
      ]
      "selector" = {
        "app" = "nginx"
      }
      "type" = "LoadBalancer"
    }
  }

  wait_for = {
    fields = {
      "status.readyReplicas" = "1"
    }
  }
}

resource "kubernetes_manifest" "nginx-deployment" {
  manifest = {
    "apiVersion" = "apps/v1"
    "kind"       = "Deployment"
    "metadata" = {
      "labels" = {
        "app" = "nginx"
      }
      "name" = "nginx"
    }
    "spec" = {
      "replicas" = 1
      "selector" = {
        "matchLabels" = {
          "app" = "nginx"
        }
      }
      "template" = {
        "metadata" = {
          "labels" = {
            "app" = "nginx"
          }
        }
        "spec" = {
          "containers" = [
            {
              "image" = "nginx:latest"
              "name"  = "nginx"
              "ports" = [
                {
                  "containerPort" = 80
                  "name"          = "http"
                },
              ]
              "readinessProbe" = {
                "httpGet" = {
                  "path" = "/"
                  "port" = 80
                }
              }
              "livenessProbe" = {
                "httpGet" = {
                  "path" = "/"
                  "port" = 80
                }
              }
            },
          ]
        }
      }
    }
  }

  wait_for = {
    fields = {
      # Check an ingress has an IP
      "status.loadBalancer.hostname" = "^example\\.com$"
    }
  }
}
