apiVersion: certmanager.k8s.io/v1alpha1
kind: Certificate
metadata:
  name: ${dns_zone_name}
  namespace: ${namespace}
spec:
  secretName: ${dns_zone_name}-tls
  issuerRef:
    name: ${issuer_name}
    kind: ClusterIssuer
  commonName: ${domain_name}
  dnsNames:
  - ${domain_name}
  acme:
    config:
    - http01:
        ingressClass: nginx
      domains:
      - ${domain_name}
