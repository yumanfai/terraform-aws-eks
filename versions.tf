## requirements

terraform {
  required_providers {
    kustomization = {
      source  = "kbst/kustomization"
      version = "0.7.1"
    }
  }
  required_version = ">= 0.13"
}

provider "kustomization" {
  kubeconfig_path = var.kubeconfig_path
  kubeconfig_raw = yamlencode(var.kubeconfig)
}