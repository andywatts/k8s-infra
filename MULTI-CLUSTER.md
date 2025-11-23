# Multi-Cluster Structure

## Overview

Each cluster (dev, staging, prod) gets its own:
- Directory: `clusters/dev/`, `clusters/staging/`
- ApplicationSet: `applicationset-dev.yaml`, `applicationset-staging.yaml`

## Current State

**Dev Cluster:** Running (GKE us-west2-a)
- ApplicationSet: `dev-cluster-apps` deployed
- Sample app: `dev-sample-app` (2 nginx pods in `sample-app` namespace)

**Staging Cluster:** Not yet created
- Directory: `clusters/staging/` ready
- ApplicationSet: `applicationset-staging.yaml` ready (update server URL when cluster exists)

## Structure

```
k8s-apps/
├── clusters/
│   ├── dev/
│   │   └── sample-app/
│   │       ├── deployment.yaml
│   │       └── service.yaml
│   └── staging/
│       └── .gitkeep (apps go here when staging cluster exists)
├── applicationset-dev.yaml
└── applicationset-staging.yaml
```

## Deploy to Dev Cluster

```bash
cd /Users/andywatts/Code/infra/k8s-apps

# Add new app
mkdir -p clusters/dev/my-app
# Create manifests in clusters/dev/my-app/
git add . && git commit -m "Add my-app to dev" && git push

# ArgoCD auto-discovers within 3 minutes
kubectl get applications -n argocd
kubectl get pods -n my-app
```

## When Staging Cluster is Ready

1. **Create staging cluster** (Terraform in gcp/projects/staging/)

2. **Get staging cluster credentials:**
```bash
gcloud container clusters get-credentials staging-cluster --zone=us-west2-a
```

3. **Get staging cluster API server URL:**
```bash
kubectl cluster-info | grep "Kubernetes control plane"
```

4. **Update applicationset-staging.yaml:**
```yaml
destination:
  server: https://<staging-cluster-api-url>  # Update this
  namespace: '{{path.basename}}'
```

5. **Add staging ArgoCD ApplicationSet to staging cluster:**
```bash
kubectl apply -f applicationset-staging.yaml
```

6. **Copy apps from dev to staging:**
```bash
cp -r clusters/dev/sample-app clusters/staging/
git add . && git commit -m "Add sample-app to staging" && git push
```

## Differences Between Clusters

If dev and staging need different configs (replicas, resources, etc.):

**Option 1: Separate files** (current - simple)
```
clusters/dev/app/deployment.yaml     # 2 replicas
clusters/staging/app/deployment.yaml # 3 replicas
```

**Option 2: Kustomize** (add later if needed)
```
apps/sample-app/
  base/
  overlays/
    dev/
    staging/
```

Start with Option 1, move to Option 2 if you have many apps with similar patterns.

## Cleanup Old Namespaces

```bash
# Remove old test deployments
kubectl delete ns sample-app-dev sample-app-staging
```

