apiVersion: cert-manager.io/v1alpha2
kind: ClusterIssuer
metadata:
  name: ${name}
  namespace: ${namespace}
spec:
  acme:
    email: ${acme_email}
    server: ${server}

    # Name of a secret used to store the ACME account private key
    privateKeySecretRef:
      name: ${name}-account-key

    solvers:
    - http01:
        ingress:
          class: nginx
