# Kong API Gateway

Kong Ingress Controller in DB-less mode, deployed via ArgoCD.

## Access

**###** Proxy (LoadBalancer)
```bash
kubectl get svc -n kong kong-kong-proxy
# Use external IP for routing traffic
```

### Admin API (ClusterIP)
```bash
kubectl port-forward -n kong svc/dev-kong-kong-admin 8001:8001
curl http://localhost:8001/routes
```

### Manager GUI (ClusterIP)
```bash
kubectl port-forward -n kong svc/dev-kong-kong-manager 8002:8002
open http://localhost:8002
```

## Add Kong to Your App

**1. Create Ingress in your app's chart:**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ .Values.name }}
  annotations:
    konghq.com/plugins: {{ .Values.name }}-rate-limit
spec:
  ingressClassName: kong
  rules:
  - host: {{ .Values.ingress.host }}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: {{ .Values.name }}
            port:
              number: 80
```

**2. Add Kong plugin (optional):**

```yaml
apiVersion: configuration.konghq.com/v1
kind: KongPlugin
metadata:
  name: {{ .Values.name }}-rate-limit
plugin: rate-limiting
config:
  minute: 100
  policy: local
```

**3. Test:**

```bash
KONG_IP=$(kubectl get svc -n kong kong-kong-proxy -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "$KONG_IP your-app.dev.local" | sudo tee -a /etc/hosts
curl http://your-app.dev.local
```

## Common Plugins

Add to ingress annotation: `konghq.com/plugins: plugin-name`

- **rate-limiting** - Limit requests per minute/hour
- **cors** - CORS headers
- **key-auth** - API key authentication
- **jwt** - JWT authentication
- **request-transformer** - Modify requests
- **ip-restriction** - IP whitelist/blacklist

[Full plugin list](https://docs.konghq.com/hub/)

## Monitoring

```bash
# Logs
kubectl logs -n kong -l app.kubernetes.io/name=kong -f

# Metrics (Prometheus)
kubectl port-forward -n kong svc/kong-kong-proxy 8100:8100
curl http://localhost:8100/metrics | grep kong_

# Status
kubectl get pods,svc -n kong
kubectl get ingress --all-namespaces
```

## Troubleshooting

### LoadBalancer stuck pending
```bash
kubectl describe svc kong-kong-proxy -n kong
gcloud compute project-info describe --project=development-690488 | grep -A 2 EXTERNAL_IPS
```

### Route not working
```bash
# Check ingress exists
kubectl get ingress -n your-app

# Check Kong knows about it
kubectl port-forward -n kong svc/kong-kong-admin 8001:8001
curl http://localhost:8001/routes | jq
```

### Plugin not applied
```bash
# Verify plugin exists
kubectl get kongplugins -n your-app

# Check ingress annotation
kubectl get ingress your-app -n your-app -o yaml | grep konghq.com/plugins
```

## Configuration

**Default values:** `kong/chart/values.yaml`  
**Environment overrides:** `kong/values/dev.yaml`, `kong/values/staging.yaml`

Update and push - ArgoCD auto-syncs.

## Resources

- [Kong Docs](https://docs.konghq.com/)
- [Ingress Controller](https://docs.konghq.com/kubernetes-ingress-controller/)
- [Plugin Hub](https://docs.konghq.com/hub/)
- [CRD Reference](https://docs.konghq.com/kubernetes-ingress-controller/latest/references/custom-resources/)
