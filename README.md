# Nginx ingress controller for Kubernetes

- [Nginx ingress controller for Kubernetes](#nginx-ingress-controller-for-kubernetes)
  - [Features](#features)
  - [Before you begin](#before-you-begin)
    - [GCE configuration](#gce-configuration)
  - [Terraform initialization](#terraform-initialization)
  - [Installation](#installation)
  - [Uninstall and cleanup](#uninstall-and-cleanup)

Terraform configuration for deploying Nginx ingress controller in a Kubernetes
cluster

## Features

- [x] GKE support.
- [x] Let's Encrypt wildcard certificate generation using
      [cert-manager](https://cert-manager.readthedocs.io/en/latest/).

## Before you begin

The following prerequisites need to be installed and configured:

- [Terraform](https://www.terraform.io/downloads.html)
- [Google Cloud SDK](https://cloud.google.com/sdk/install) (run
  `gcloud components update` to update SDK to the latest version if you already
  have it installed)
- GKE cluster must be created (you may use
  [this Terraform configuration](https://github.com/Wi3ard/gke-cluster-terraform)
  to create it)

### GCE configuration

`GOOGLE_APPLICATION_CREDENTIALS` environment variable must be configured to
point to GCE JSON key file. For example (PowerShell):

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS = "C:/mykeys/gce-default.json"
```

Bash:

```shell
export GOOGLE_APPLICATION_CREDENTIALS = ~/mykeys/gce-default.json
```

## Terraform initialization

Copy [terraform.tfvars.example](terraform.tfvars.example) file to
`terraform.tfvars` and set input variables values as per your needs. Then
initialize Terraform with `init` command:

```shell
terraform init -backend-config "bucket=$BUCKET_NAME" -backend-config "prefix=apps/$CLUSTER_NAME/nginx-ingress"
```

- `$CLUSTER_NAME` should be replaced with the name of a cluster.
- `$BUCKET_NAME` should be replaced with a GCS Terraform state storage bucket
  name.

## Installation

To apply the Terraform plan, run:

```shell
terraform apply
```

## Uninstall and cleanup

To remove the Terraform plan, run:

```shell
terraform destroy
```
