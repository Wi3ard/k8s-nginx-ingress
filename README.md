# Nginx ingress controller for Kubernetes

- [Nginx ingress controller for Kubernetes](#nginx-ingress-controller-for-kubernetes)
  - [Features](#features)
  - [Before you begin](#before-you-begin)
  - [Terraform initialization](#terraform-initialization)
  - [Installation](#installation)
  - [Uninstall and cleanup](#uninstall-and-cleanup)

Terraform configuration for deploying Nginx ingress controller in a Kubernetes cluster

## Features

- [X] EKS support.
- [X] Let's Encrypt certificates generation using [cert-manager](https://cert-manager.readthedocs.io/en/latest/).
- [X] NO DNS providers support.

## Before you begin

TODO: Add AWS EKS prerequisites

The following prerequisites need to be installed and configured:

- [Terraform](https://www.terraform.io/downloads.html)
- [Helm](https://helm.sh/) needs to be installed in the Kubernetes cluster

## Terraform initialization

Copy [terraform.tfvars.example](terraform.tfvars.example) file to `terraform.tfvars` and set input variables values as per your needs. Then initialize Terraform with `init` command:

```shell
terraform init -backend-config "bucket=$BUCKET_NAME" -backend-config "prefix=apps/$CLUSTER_NAME/traefik" -backend-config "region=$REGION"
```

- `$REGION` should be replaced with a region name.
- `$CLUSTER_NAME` should be replaced with the name of a cluster.
- `$BUCKET_NAME` should be replaced with a GCS Terraform state storage bucket name.

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

The `cert-manager` Helm chart included in this plan creates several [Custom Resource Definitions](https://docs.okd.io/latest/admin_guide/custom_resource_definitions.html) that have to be deleted manually:

```shell
$ kubectl delete crd certificates.certmanager.k8s.io -n kube-system
customresourcedefinition.apiextensions.k8s.io "certificates.certmanager.k8s.io" deleted

$ kubectl delete crd clusterissuers.certmanager.k8s.io -n kube-system
customresourcedefinition.apiextensions.k8s.io "clusterissuers.certmanager.k8s.io" deleted

$ kubectl delete crd issuers.certmanager.k8s.io -n kube-system
customresourcedefinition.apiextensions.k8s.io "issuers.certmanager.k8s.io" deleted
```
