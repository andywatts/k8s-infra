# k8s-apps

GitOps repository for Kubernetes applications managed by ArgoCD.

## Structure

```
charts/
  sample-app/          # Nginx example app
  kong/                # Kong API Gateway (DB-less)
values/
  dev/
    sample-app.yaml    # Dev config
    kong.yaml          # Kong dev config
manifests/
  sample-app-ingress.yaml  # Kong ingress + plugins
applicationset-dev.yaml    # ArgoCD auto-deployment
```

## Quick Start

```bash
# Connect to cluster
gcloud container clusters get-credentials dev-cluster \
  --region=us-west2 --project=development-690488

# Deploy applications
kubectl apply -f applicationset-dev.yaml

# Check status
kubectl get applications -n argocd
kubectl get pods -A
```

## Kong API Gateway

Kong is deployed with Ingress Controller in DB-less mode.

```bash
# Get Kong IP
kubectl get svc -n kong dev-kong-kong-proxy

# Current: 35.235.100.23
```

**Access sample-app via Kong:**
```bash
# Add to /etc/hosts
echo "35.235.100.23 sample-app.dev.local" | sudo tee -a /etc/hosts

# Test
curl http://sample-app.dev.local
```

**Features:**
- ✅ Rate limiting (100 req/min)
- ✅ CORS enabled
- ✅ DB-less mode (config via CRDs)

**Documentation:**
- [KONG.md](./KONG.md) - Complete guide
- [KONG-QUICK-START.md](./KONG-QUICK-START.md) - Fast setup
- [KONG-INFRASTRUCTURE.md](./KONG-INFRASTRUCTURE.md) - GCP infrastructure

## Add New Application

```bash
# 1. Create Helm chart
mkdir -p charts/my-app/templates

# 2. Add Chart.yaml, values.yaml, templates/

# 3. Create environment config
cat > values/dev/my-app.yaml <<EOF
replicaCount: 2
image:
  repository: my-image
  tag: latest
EOF

# 4. Update applicationset-dev.yaml
# Add "- app: my-app" to the list

# 5. Deploy
git add . && git commit -m "Add my-app" && git push
```

ArgoCD syncs automatically within 3 minutes.

## Current Deployments

| App | Status | Description |
|-----|--------|-------------|
| **kong** | ✅ Healthy | API Gateway & Ingress Controller |
| **sample-app** | ✅ Healthy | Nginx example with Kong ingress |

## Kong Ingress for Your App

```yaml
# In values/dev/your-app.yaml
ingress:
  enabled: true
  host: your-app.dev.local
```

Or apply manually:
```bash
kubectl apply -f manifests/your-app-ingress.yaml
```

## Useful Commands

```bash
# View applications
kubectl get applications -n argocd

# Kong resources
kubectl get ingress,kongplugins -A

# Force ArgoCD sync
kubectl patch app my-app -n argocd \
  --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

# Kong admin API
kubectl port-forward -n kong svc/dev-kong-kong-admin 8001:8001
curl http://localhost:8001/
```

## Documentation

- [HELM-STRUCTURE.md](./HELM-STRUCTURE.md) - Chart organization
- [MULTI-CLUSTER.md](./MULTI-CLUSTER.md) - Multi-cluster setup
- [SETUP-COMPLETE.md](./SETUP-COMPLETE.md) - Setup details

---
**GitOps:** Push to main → ArgoCD syncs → Kubernetes updates
