# k8s-infra

Kubernetes platform infrastructure charts and ArgoCD configuration.

## Structure

```
argocd/
  projects/
    kong.yaml                # Kong AppProject (namespace: kong)
    sample-app.yaml          # sample-app AppProject (namespace: sample-app)
  applicationsets/
    dev.yaml                 # Dev environment apps
    staging.yaml             # Staging environment apps
kong/                        # Platform service: Kong API Gateway
  chart/                     # Helm chart
    Chart.yaml
    values.yaml
    templates/
  values/                    # Environment overrides
    dev.yaml
    staging.yaml
```

**Repo Purpose:** Infrastructure team's repository for platform services (Kong, future: Istio, cert-manager, etc.) and ArgoCD configuration.

**Application repos:** Each app team owns their repo (e.g., `sample-app/`) with their own Helm chart.

## Architecture

**Platform Infrastructure** (this repo):
- Kong API Gateway
- Shared platform services
- ArgoCD configuration

**Applications** (separate repos):
- [sample-app](https://github.com/andywatts/sample-app) - Each app owns its Helm chart
- Future apps follow same pattern

### ArgoCD Components

**AppProjects** (`argocd/projects/`):
- `kong.yaml` - Kong can only deploy to `kong` namespace
- `sample-app.yaml` - sample-app can only deploy to `sample-app` namespace
- Each app isolated to its own namespace (security)

**ApplicationSets** (`argocd/applicationsets/`):
- `dev.yaml` - Generates dev-kong, dev-sample-app
- `staging.yaml` - Generates staging-kong, staging-sample-app
- Automates multi-app deployment from templates

## Quick Start

```bash
# Connect to cluster
gcloud container clusters get-credentials dev-cluster \
  --region=us-west2 --project=development-690488

# Deploy AppProjects and ApplicationSets
kubectl apply -f argocd/projects/
kubectl apply -f argocd/applicationsets/dev.yaml

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

**App teams:** Create your own repo with Helm chart

```bash
# 1. Create app repo
mkdir my-app && cd my-app
mkdir -p chart/templates environments

# 2. Add Helm chart + environment values
# 3. Push to GitHub

# 4. Infra team: Update k8s-infra repo
# - Create argocd/projects/my-app.yaml (restrict to namespace)
# - Add entry to argocd/applicationsets/dev.yaml
```

## Add New Infrastructure Service

**Infra team:** Add to this repo

```bash
# 1. Create service directory
mkdir -p my-service/chart/templates my-service/values

# 2. Add Helm chart to my-service/chart/
# 3. Add my-service/values/dev.yaml and staging.yaml

# 4. Create argocd/projects/my-service.yaml
# 5. Add to argocd/applicationsets/dev.yaml

# 6. Commit and push
git add . && git commit -m "Add my-service" && git push
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
