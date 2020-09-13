terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
    }
    helm = {
      source = "hashicorp/helm"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    local = {
      source = "hashicorp/local"
    }
    null = {
      source = "hashicorp/null"
    }
    template = {
      source = "hashicorp/template"
    }
  }

  required_version = ">= 0.13.0, < 0.14"
}

/*
 * Terraform providers.
 */

provider "google" {
  project = var.google_project_id
  region  = var.region
  version = ">= 3.38.0, < 4.0"
}

provider "helm" {
  version = ">= 1.3.0, < 2.0"
}

provider "kubernetes" {
  version = ">= 1.13.2, < 2.0"
}

provider "local" {
  version = ">= 1.4.0, < 2.0"
}

provider "null" {
  version = ">= 2.1.2, < 3.0"
}

provider "template" {
  version = ">= 2.1.2, < 3.0"
}
