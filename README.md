# k8s-apps

Platform infrastructure charts and ArgoCD configuration.

## Structure

```
charts/
  kong/                # Kong API Gateway (DB-less)
values/
  dev/
    kong.yaml          # Kong dev config
appproject-dev.yaml        # ArgoCD project (RBAC, repo access)
applicationset-dev.yaml    # ArgoCD ApplicationSet (auto-deployment)
```

## Architecture

**Platform Infrastructure** (this repo):
- Kong API Gateway
- Shared platform services

**Applications** (separate repos):
- [sample-app](https://github.com/andywatts/sample-app) - Each app owns its Helm chart
- Future apps follow same pattern

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

Each app lives in its own repo with its Helm chart.

```bash
# 1. Create new repo
mkdir my-app && cd my-app
mkdir -p chart/templates environments

# 2. Add Helm chart (Chart.yaml, values.yaml, templates/)

# 3. Add environment configs
cat > environments/values-dev.yaml <<EOF
replicaCount: 2
image:
  repository: my-image
  tag: latest
EOF

# 4. Push to GitHub
git init && git add . && git commit -m "Initial commit"
gh repo create my-app --public --source=. --push

# 5. Update k8s-apps repo
# - Add repo to appproject-dev.yaml
# - Add app to applicationset-dev.yaml

# 6. Deploy
git add . && git commit -m "Add my-app" && git push
```

ArgoCD syncs automatically.

## Current Deployments

| App | Status | Description |
|-----|--------|-------------|
| **kong** | ✅ Healthy | API Gateway & Ingress Controller |
| **sample-app** | ✅ Healthy | Nginx example with Kong ingress |

## Kong Ingress for Your App

Add to your app's `chart/templates/ingress.yaml`:

```yaml
{{- if .Values.ingress.enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ .Chart.Name }}
  annotations:
    kubernetes.io/ingress.class: "kong"
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
            name: {{ .Chart.Name }}
            port:
              number: 80
{{- end }}
```

Enable in `environments/values-dev.yaml`:
```yaml
ingress:
  enabled: true
  host: your-app.dev.local
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

- [KONG.md](./KONG.md) - Kong configuration
- [KONG-QUICK-START.md](./KONG-QUICK-START.md) - Quick setup

---
**GitOps:** Push to repo → ArgoCD syncs → Kubernetes updates (automated)
