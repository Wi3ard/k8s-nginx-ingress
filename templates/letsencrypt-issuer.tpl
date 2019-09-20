apiVersion: certmanager.k8s.io/v1alpha1
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

    # ACME HTTP-01 provider configurations
    http01: {}
