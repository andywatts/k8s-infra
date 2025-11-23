# k8s-apps

GitOps repo for Kubernetes applications managed by ArgoCD.

## Structure

```
clusters/
  dev/
    sample-app/        # Apps deployed to dev cluster
  staging/             # Apps for staging cluster (when created)
applicationset-dev.yaml      # Auto-discovers dev cluster apps
applicationset-staging.yaml  # For future staging cluster
```

Each cluster gets its own directory and ApplicationSet.

## Setup

1. **Connect to cluster:**
```bash
gcloud container clusters get-credentials dev-cluster --zone=us-west2-a --project=development-690488
```

2. **Apply dev ApplicationSet:**
```bash
kubectl apply -f applicationset-dev.yaml
```

3. **Access ArgoCD UI:**
```bash
# Get password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port forward
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Login: `admin` / (password from above)

## Deploy New App to Dev

```bash
mkdir -p clusters/dev/my-app
# Add manifests (deployment.yaml, service.yaml, etc.)
git add . && git commit -m "Add my-app" && git push
```

ArgoCD auto-discovers and deploys to dev cluster.

## When Staging Cluster is Ready

1. Add apps to `clusters/staging/`
2. Update `server` URL in `applicationset-staging.yaml`
3. Apply to staging cluster: `kubectl apply -f applicationset-staging.yaml`