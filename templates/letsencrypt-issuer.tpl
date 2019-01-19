apiVersion: certmanager.k8s.io/v1alpha1
kind: ClusterIssuer
metadata:
  name: ${name}
  namespace: ${namespace}
spec:
  acme:
    server: ${server}
    email: ${acme_email}

    # Name of a secret used to store the ACME account private key
    privateKeySecretRef:
      name: ${name}-account-key

    # ACME DNS-01 provider configurations
    dns01:
      providers:
        - name: gcs-dns
          clouddns:
            # A secretKeyRef to a google cloud json service account
            serviceAccountSecretRef:
              name: ${gcs_service_account_secret}
              key: gcs.json
            # The project in which to update the DNS zone
            project: ${google_project_id}
