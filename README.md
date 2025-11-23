# k8s-apps

GitOps repo for Kubernetes applications managed by ArgoCD.

## Structure

```
apps/
  sample-app/
    base/              # Base manifests
    overlays/
      dev/             # Dev-specific values
      staging/         # Staging-specific values
applicationsets/
  dev.yaml             # Auto-discovers dev overlays
  staging.yaml         # Auto-discovers staging overlays
```

## Setup

1. **Connect to cluster:**
```bash
gcloud container clusters get-credentials dev-cluster --zone=us-west2-a --project=development-690488
```

2. **Apply ApplicationSets:**
```bash
kubectl apply -f applicationsets/
```

3. **Access ArgoCD UI:**
```bash
# Get password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port forward
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Login: `admin` / (password from above)

## Deploy New App

Create base manifests + environment overlays:

```bash
mkdir -p apps/my-app/{base,overlays/{dev,staging}}
# Add base manifests to apps/my-app/base/
# Add kustomization.yaml to each overlay
git commit && git push
```

ArgoCD auto-discovers and deploys to both environments.