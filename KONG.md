**#** Kong API Gateway - DB-less Mode

Kong API Gateway deployed via ArgoCD with DB-less configuration for declarative configuration management.

## 🎯 Overview

Kong is deployed as:
- **Ingress Controller**: Native Kubernetes integration
- **DB-less Mode**: Configuration via CRDs (no PostgreSQL needed)
- **High Availability**: Multi-replica in staging with autoscaling
- **GitOps Ready**: All config in Git, managed by ArgoCD

## 📁 Structure

```
charts/kong/
  Chart.yaml         # Kong Helm chart dependency
  values.yaml        # Default values
  templates/         # (empty - uses upstream chart)

values/
  dev/kong.yaml      # Dev config: 1 replica, minimal resources
  staging/kong.yaml  # Staging config: 2+ replicas, HA, autoscaling
```

## 🚀 Deployment

### Prerequisites

1. **ArgoCD installed** in the cluster
2. **Helm 3** for local testing
3. **kubectl** configured for your cluster

### Deploy to Dev

Kong is automatically deployed via ArgoCD ApplicationSet:

```bash
# Connect to dev cluster
gcloud container clusters get-credentials dev-cluster \
  --zone=us-west2-a \
  --project=development-690488

# Kong deploys automatically via applicationset-dev.yaml
# Check deployment status
kubectl get applications -n argocd | grep kong

# Verify Kong pods
kubectl get pods -n kong
```

### Manual Deployment (if needed)

```bash
# Add Kong Helm repo
helm repo add kong https://charts.konghq.com
helm repo update

# Deploy manually (for testing)
helm install kong-dev charts/kong \
  -f values/dev/kong.yaml \
  -n kong \
  --create-namespace
```

## 🔧 Configuration

### DB-less Mode

Kong runs without a database. Configuration is stored in Kubernetes CRDs:
- `Ingress` - Standard Kubernetes ingress
- `KongPlugin` - Kong plugins (rate limiting, CORS, etc.)
- `KongIngress` - Advanced Kong-specific config
- `KongConsumer` - API consumers for authentication

### Environment Differences

| Feature | Dev | Staging |
|---------|-----|---------|
| Replicas | 1 | 2 (autoscale to 5) |
| CPU Limit | 300m | 1000m |
| Memory Limit | 256Mi | 1Gi |
| Admin GUI | Enabled | Enabled |
| Logging | Debug | Notice |
| LoadBalancer | Yes | Yes |

## 🌐 Accessing Kong

### Get LoadBalancer IP

```bash
# Get proxy service external IP
kubectl get svc -n kong kong-kong-proxy

# Example output:
# NAME              TYPE           EXTERNAL-IP    PORT(S)
# kong-kong-proxy   LoadBalancer   34.82.xxx.xxx  80:31234/TCP,443:31567/TCP
```

### Test Kong Proxy

```bash
# Get external IP
KONG_PROXY_IP=$(kubectl get svc -n kong kong-kong-proxy \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Test Kong is responding
curl http://$KONG_PROXY_IP

# Should return: {"message":"no Route matched with those values"}
```

### Access Admin API

The Admin API is ClusterIP only (not exposed externally) for security.

```bash
# Port-forward to access Admin API
kubectl port-forward -n kong svc/kong-kong-admin 8001:8001

# In another terminal, test Admin API
curl http://localhost:8001/

# List all services
curl http://localhost:8001/services

# List all routes
curl http://localhost:8001/routes
```

### Access Admin GUI (Manager)

Enabled in dev and staging for easier management.

```bash
# Port-forward to access Manager
kubectl port-forward -n kong svc/kong-kong-manager 8002:8002

# Open in browser
open http://localhost:8002
```

## 📝 Using Kong with Your Apps

### Example: Expose sample-app via Kong

The `sample-app` already has Kong Ingress configured. Here's how it works:

**1. Ingress Resource** (`charts/sample-app/templates/ingress.yaml`)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: sample-app
  annotations:
    kubernetes.io/ingress.class: kong
    konghq.com/plugins: sample-app-rate-limit,sample-app-cors
spec:
  ingressClassName: kong
  rules:
  - host: sample-app.dev.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: sample-app
            port:
              number: 80
```

**2. Kong Plugins** (rate limiting, CORS)

```yaml
apiVersion: configuration.konghq.com/v1
kind: KongPlugin
metadata:
  name: sample-app-rate-limit
plugin: rate-limiting
config:
  minute: 100
  policy: local
```

**3. Test the Route**

```bash
# Add host to /etc/hosts
echo "$KONG_PROXY_IP sample-app.dev.local" | sudo tee -a /etc/hosts

# Test the route
curl http://sample-app.dev.local

# Should return nginx welcome page
```

### Create Kong Ingress for Your App

**Step 1: Enable Ingress in values**

```yaml
# values/dev/your-app.yaml
ingress:
  enabled: true
  host: your-app.dev.local
  path: /
  annotations:
    konghq.com/plugins: your-app-rate-limit
```

**Step 2: Define plugins**

```yaml
# In your app's values
kong:
  plugins:
    rateLimit:
      enabled: true
      minute: 100
    cors:
      enabled: true
      origins:
        - "*"
```

**Step 3: Deploy**

```bash
git add . && git commit -m "Enable Kong ingress for your-app"
git push

# ArgoCD auto-syncs and creates the route
```

## 🔌 Kong Plugins

### Available Plugins (DB-less mode)

Kong comes with 40+ plugins. Common ones:

**Traffic Control:**
- `rate-limiting` - Rate limit requests
- `request-size-limiting` - Limit request body size
- `response-ratelimiting` - Rate limit based on response headers

**Authentication:**
- `key-auth` - API key authentication
- `basic-auth` - Basic authentication
- `jwt` - JWT authentication
- `oauth2` - OAuth 2.0

**Security:**
- `cors` - CORS support
- `ip-restriction` - IP whitelist/blacklist
- `bot-detection` - Block bots

**Transformations:**
- `request-transformer` - Modify requests
- `response-transformer` - Modify responses

**Logging & Monitoring:**
- `prometheus` - Prometheus metrics
- `datadog` - Datadog integration
- `file-log` - Log to file

### Example: JWT Authentication

**1. Create Kong Plugin**

```yaml
apiVersion: configuration.konghq.com/v1
kind: KongPlugin
metadata:
  name: my-app-jwt
  namespace: my-app
plugin: jwt
config:
  secret_is_base64: false
```

**2. Create Kong Consumer**

```yaml
apiVersion: configuration.konghq.com/v1
kind: KongConsumer
metadata:
  name: user-123
  namespace: my-app
username: user-123
credentials:
- jwt
```

**3. Create JWT Credential**

```yaml
apiVersion: configuration.konghq.com/v1
kind: KongCredential
metadata:
  name: jwt-credential
  namespace: my-app
type: jwt
consumerRef: user-123
config:
  key: user-123-key
  secret: my-secret-key
```

**4. Apply to Ingress**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  annotations:
    konghq.com/plugins: my-app-jwt
```

## 🔍 Monitoring & Debugging

### Check Kong Status

```bash
# Get Kong pods
kubectl get pods -n kong

# Check Kong logs
kubectl logs -n kong -l app.kubernetes.io/name=kong

# Check Ingress Controller logs
kubectl logs -n kong -l app.kubernetes.io/component=controller
```

### Verify Ingress Resources

```bash
# List all ingresses
kubectl get ingress --all-namespaces

# Describe specific ingress
kubectl describe ingress sample-app -n sample-app

# Check Kong configuration
kubectl get kongplugins --all-namespaces
kubectl get kongingresses --all-namespaces
kubectl get kongconsumers --all-namespaces
```

### Debug Route Issues

```bash
# Port-forward to Admin API
kubectl port-forward -n kong svc/kong-kong-admin 8001:8001

# List all routes Kong knows about
curl http://localhost:8001/routes | jq

# List all services
curl http://localhost:8001/services | jq

# Check specific route
curl http://localhost:8001/routes/<route-id>
```

### Prometheus Metrics

Kong exposes Prometheus metrics on port 8100:

```bash
# Port-forward to metrics
kubectl port-forward -n kong svc/kong-kong-proxy 8100:8100

# Scrape metrics
curl http://localhost:8100/metrics
```

## 🚨 Troubleshooting

### Issue: No LoadBalancer External IP

```bash
# Check service status
kubectl get svc -n kong kong-kong-proxy

# If stuck in "Pending", check GKE quotas
gcloud compute project-info describe --project=development-690488
```

**Solution**: Ensure your GCP project has available external IP quota.

### Issue: Ingress not working

**Check 1: Kong Ingress Controller running**
```bash
kubectl get pods -n kong -l app.kubernetes.io/component=controller
```

**Check 2: Ingress has IP assigned**
```bash
kubectl get ingress -n sample-app
# Should show Kong proxy IP in ADDRESS column
```

**Check 3: Service exists and is healthy**
```bash
kubectl get svc -n sample-app
kubectl get endpoints -n sample-app
```

### Issue: Rate limiting not working

**Check plugin configuration:**
```bash
kubectl describe kongplugin sample-app-rate-limit -n sample-app
```

**Verify plugin is attached to ingress:**
```bash
kubectl get ingress sample-app -n sample-app -o yaml | grep plugins
```

### Issue: CORS errors

**Check CORS plugin config:**
```bash
kubectl get kongplugin sample-app-cors -n sample-app -o yaml
```

**Verify origins are correct:**
```yaml
config:
  origins:
  - "https://your-frontend.com"  # Must match exactly
  credentials: true
```

## 🔐 Security Best Practices

1. **Admin API**: Never expose externally (keep as ClusterIP)
2. **Manager UI**: Only enable in non-prod or use kubectl port-forward
3. **TLS**: Enable TLS termination at Kong (configure certificates)
4. **Rate Limiting**: Always enable for public APIs
5. **IP Restriction**: Use IP whitelisting for admin endpoints
6. **API Keys**: Use authentication plugins for sensitive endpoints

## 📚 Additional Resources

- [Kong Documentation](https://docs.konghq.com/)
- [Kong Ingress Controller](https://docs.konghq.com/kubernetes-ingress-controller/)
- [DB-less Mode](https://docs.konghq.com/gateway/latest/production/deployment-topologies/db-less-and-declarative-config/)
- [Kong Plugins Hub](https://docs.konghq.com/hub/)
- [Kong Custom Resources](https://docs.konghq.com/kubernetes-ingress-controller/latest/references/custom-resources/)

## 🎓 Next Steps

1. **Deploy Kong**: Push changes and let ArgoCD deploy
2. **Get LoadBalancer IP**: `kubectl get svc -n kong`
3. **Test sample-app route**: Add host to `/etc/hosts` and curl
4. **Enable plugins**: Try rate limiting, CORS, JWT auth
5. **Monitor**: Set up Prometheus scraping
6. **Custom domains**: Configure DNS to point to Kong LoadBalancer
7. **TLS certificates**: Add cert-manager for automatic TLS

