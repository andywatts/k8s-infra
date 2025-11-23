# k8s-infra

Platform infrastructure services and ArgoCD configuration for Kubernetes.

## Structure

```
argocd/
  projects/           # AppProjects (namespace isolation)
  applicationsets/    # ApplicationSets (per environment)
kong/                 # Kong API Gateway
  chart/              # Helm chart
  values/             # Environment configs (dev.yaml, staging.yaml)
```

**Scope:** Infrastructure team manages platform services (Kong, future: Istio, cert-manager).  
**Apps:** Teams own separate repos ([sample-app](https://github.com/andywatts/sample-app)) with their charts.

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

Ingress Controller in DB-less mode. Get proxy IP:
```bash
kubectl get svc -n kong dev-kong-kong-proxy
```

Test:
```bash
echo "KONG_IP sample-app.dev.local" | sudo tee -a /etc/hosts
curl http://sample-app.dev.local
```

## Add New Service

**Infrastructure service** (infra team):
```bash
mkdir -p my-service/chart/templates my-service/values
# Add chart + values/dev.yaml, values/staging.yaml
# Create argocd/projects/my-service.yaml
# Add to argocd/applicationsets/dev.yaml
```

**Application** (app team):
```bash
# Create separate repo with chart/ and environments/
# Infra team adds argocd/projects/my-app.yaml + ApplicationSet entry
```

## Commands

```bash
# View applications
kubectl get applications -n argocd

# Force sync
kubectl patch app my-app -n argocd \
  --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
```

---
**GitOps:** Push to repo → ArgoCD syncs automatically
