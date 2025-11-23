# k8s-apps

GitOps repository for Kubernetes applications managed by ArgoCD. Deploy once, sync everywhere.

## 📁 Structure

```
charts/                  # Helm charts (DRY - shared across clusters)
  sample-app/           # Example nginx app
  kong/                 # Kong API Gateway
values/                 # Environment-specific overrides
  dev/
    *.yaml              # Dev cluster configs
  staging/
    *.yaml              # Staging cluster configs
applicationset-dev.yaml     # Auto-deploy to dev
applicationset-staging.yaml # Auto-deploy to staging
```

## 🚀 Quick Start

### 1. Connect to Cluster
```bash
gcloud container clusters get-credentials dev-cluster \
  --zone=us-west2-a --project=development-690488
```

### 2. Deploy Applications
```bash
kubectl apply -f applicationset-dev.yaml
```

### 3. Access ArgoCD
```bash
# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Port forward to UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Open https://localhost:8080 (admin / password-from-above)
```

## 🌐 Kong API Gateway

Kong is deployed as the ingress controller with DB-less mode.

```bash
# Deploy Kong (one command)
./deploy-kong.sh dev

# Get LoadBalancer IP
kubectl get svc -n kong kong-kong-proxy

# Test Kong
curl http://<KONG_IP>
```

**Documentation:**
- [KONG-QUICK-START.md](./KONG-QUICK-START.md) - Fast track guide
- [KONG.md](./KONG.md) - Complete reference
- [KONG-INFRASTRUCTURE.md](./KONG-INFRASTRUCTURE.md) - Infrastructure & costs

**Expose your app through Kong:**
```yaml
# In values/dev/your-app.yaml
ingress:
  enabled: true
  host: your-app.example.com
kong:
  plugins:
    rateLimit:
      enabled: true
      minute: 100
```

## ➕ Add New Application

```bash
# 1. Create Helm chart
mkdir -p charts/my-app/templates

# 2. Add Chart.yaml, values.yaml, templates/

# 3. Create environment configs
cat > values/dev/my-app.yaml <<EOF
replicaCount: 2
image:
  repository: my-image
  tag: latest
EOF

# 4. Update ApplicationSet
# Add "- app: my-app" to applicationset-dev.yaml

# 5. Deploy
git add . && git commit -m "Add my-app" && git push
```

ArgoCD auto-syncs within 3 minutes.

## 🏗️ Current Deployments

| App | Dev | Staging | Description |
|-----|-----|---------|-------------|
| **sample-app** | ✅ | 🔜 | Example nginx app with Kong ingress |
| **kong** | ✅ | 🔜 | API Gateway & Ingress Controller |

## 📚 Documentation

- [HELM-STRUCTURE.md](./HELM-STRUCTURE.md) - Helm chart organization
- [MULTI-CLUSTER.md](./MULTI-CLUSTER.md) - Multi-cluster setup
- [SETUP-COMPLETE.md](./SETUP-COMPLETE.md) - Initial setup details

## 🎯 Next Steps

- [ ] Deploy Kong: `./deploy-kong.sh dev`
- [ ] Add your first app
- [ ] Configure custom domains
- [ ] Set up TLS certificates with cert-manager
- [ ] Create staging cluster
- [ ] Enable monitoring (Prometheus/Grafana)

---
**GitOps:** Push to main → ArgoCD auto-deploys → Kubernetes updates
