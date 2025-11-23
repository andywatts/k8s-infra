# Kong Quick Start Guide

Fast track to deploying and using Kong API Gateway in your cluster.

## 🚀 One-Command Deployment

```bash
# Deploy to dev cluster
./deploy-kong.sh dev

# Or deploy to staging (when ready)
./deploy-kong.sh staging
```

That's it! The script will:
- ✅ Connect to your cluster
- ✅ Apply the ApplicationSet
- ✅ Wait for Kong to be ready
- ✅ Display the LoadBalancer IP and access instructions

## ⚡ Manual Deployment (Alternative)

If you prefer manual steps:

```bash
# 1. Connect to cluster
gcloud container clusters get-credentials dev-cluster \
  --zone=us-west2-a \
  --project=development-690488

# 2. Apply ApplicationSet
kubectl apply -f applicationset-dev.yaml

# 3. Wait for Kong
kubectl get pods -n kong -w

# 4. Get LoadBalancer IP
kubectl get svc -n kong kong-kong-proxy
```

## 🎯 Quick Tests

### Test 1: Verify Kong is Responding

```bash
# Get Kong IP
KONG_IP=$(kubectl get svc -n kong kong-kong-proxy \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Test Kong proxy
curl http://$KONG_IP
# Expected: {"message":"no Route matched with those values"}
```

### Test 2: Access Admin API

```bash
# Port-forward to Admin API
kubectl port-forward -n kong svc/kong-kong-admin 8001:8001

# In another terminal, test Admin API
curl http://localhost:8001/

# List services
curl http://localhost:8001/services

# List routes
curl http://localhost:8001/routes
```

### Test 3: Check sample-app Route

The `sample-app` is already configured with Kong Ingress.

```bash
# Add host to /etc/hosts
echo "$KONG_IP sample-app.dev.local" | sudo tee -a /etc/hosts

# Test the route through Kong
curl http://sample-app.dev.local

# Should return nginx welcome page
```

### Test 4: Verify Rate Limiting

Sample-app has rate limiting enabled (100 requests/minute).

```bash
# Make multiple requests
for i in {1..105}; do
  curl -s -o /dev/null -w "%{http_code}\n" http://sample-app.dev.local
done

# First 100 should return 200
# After that should return 429 (Too Many Requests)
```

### Test 5: Verify CORS

```bash
# Test CORS headers
curl -H "Origin: http://example.com" \
  -H "Access-Control-Request-Method: POST" \
  -X OPTIONS \
  http://sample-app.dev.local -v

# Should see Access-Control-Allow-Origin headers
```

## 🔌 Add Kong to Your App

To expose your own app via Kong:

### Step 1: Update Your App's Values

```yaml
# In values/dev/your-app.yaml
ingress:
  enabled: true
  host: your-app.dev.local
  path: /
  annotations:
    konghq.com/plugins: your-app-rate-limit

kong:
  plugins:
    rateLimit:
      enabled: true
      minute: 100
```

### Step 2: Add Ingress Template

If your app doesn't have ingress template, copy from sample-app:

```bash
cp charts/sample-app/templates/ingress.yaml \
   charts/your-app/templates/ingress.yaml
```

### Step 3: Deploy

```bash
git add .
git commit -m "Enable Kong ingress for your-app"
git push

# ArgoCD will auto-sync and create the route
```

### Step 4: Test

```bash
echo "$KONG_IP your-app.dev.local" | sudo tee -a /etc/hosts
curl http://your-app.dev.local
```

## 🎛️ Kong Manager (GUI)

Kong Manager provides a web UI for managing Kong.

```bash
# Port-forward to Manager
kubectl port-forward -n kong svc/kong-kong-manager 8002:8002

# Open in browser
open http://localhost:8002
```

In Kong Manager you can:
- View all services and routes
- Configure plugins visually
- Monitor traffic metrics
- Manage consumers

## 📊 Monitoring Kong

### Check Kong Status

```bash
# Pod status
kubectl get pods -n kong

# Service status
kubectl get svc -n kong

# Ingress status
kubectl get ingress --all-namespaces

# Application status in ArgoCD
kubectl get application dev-kong -n argocd
```

### View Kong Logs

```bash
# Gateway logs
kubectl logs -n kong -l app.kubernetes.io/name=kong

# Ingress Controller logs
kubectl logs -n kong -l app.kubernetes.io/component=controller

# Follow logs
kubectl logs -n kong -l app.kubernetes.io/name=kong -f
```

### Prometheus Metrics

Kong exposes metrics on port 8100:

```bash
# Port-forward to metrics
kubectl port-forward -n kong svc/kong-kong-proxy 8100:8100

# Scrape metrics
curl http://localhost:8100/metrics

# Kong-specific metrics
curl http://localhost:8100/metrics | grep kong_
```

## 🔧 Common Tasks

### Add a Plugin to Existing Route

```bash
# Edit your app's values to enable plugin
# values/dev/your-app.yaml
kong:
  plugins:
    cors:
      enabled: true
      origins:
        - "*"

# Commit and push
git add . && git commit -m "Enable CORS for your-app" && git push

# ArgoCD auto-syncs
```

### Update Kong Configuration

```bash
# Edit Kong values
# values/dev/kong.yaml
kong:
  replicaCount: 2  # Increase replicas

# Commit and push
git add . && git commit -m "Scale Kong to 2 replicas" && git push
```

### Restart Kong

```bash
# Rollout restart
kubectl rollout restart deployment/kong-kong -n kong

# Watch status
kubectl rollout status deployment/kong-kong -n kong
```

## 🐛 Troubleshooting

### LoadBalancer IP Stuck in Pending

```bash
# Check service
kubectl describe svc kong-kong-proxy -n kong

# Check GCP quota
gcloud compute project-info describe \
  --project=development-690488 | grep -A 2 EXTERNAL_IPS
```

### Route Not Working

```bash
# Check ingress exists
kubectl get ingress -n your-app

# Check service exists
kubectl get svc -n your-app

# Check endpoints (pods backing service)
kubectl get endpoints -n your-app

# Check Kong routes
kubectl port-forward -n kong svc/kong-kong-admin 8001:8001
curl http://localhost:8001/routes | jq
```

### Plugin Not Applied

```bash
# Check plugin exists
kubectl get kongplugins -n your-app

# Check ingress annotation
kubectl get ingress your-app -n your-app -o yaml | grep plugins

# Check Kong Admin API
curl http://localhost:8001/plugins | jq
```

## 📚 Learn More

- **Full Documentation**: See [KONG.md](./KONG.md)
- **Infrastructure Guide**: See [KONG-INFRASTRUCTURE.md](./KONG-INFRASTRUCTURE.md)
- **Kong Docs**: https://docs.konghq.com/
- **Kong Plugins**: https://docs.konghq.com/hub/

## 🎓 Next Steps

1. ✅ Deploy Kong (you're here!)
2. 🔗 Expose your apps via Kong Ingress
3. 🔌 Try different plugins (JWT auth, caching, transformations)
4. 📊 Set up monitoring with Prometheus
5. 🌐 Configure custom domains and TLS certificates
6. 🚀 Deploy to staging cluster

Happy API Gateway-ing! 🎉

