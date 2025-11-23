# k8s-apps

GitOps repo for Kubernetes applications managed by ArgoCD.

## Structure

```
applicationset.yaml           # Auto-discovers apps in environments/
environments/dev/*/          # Dev environment apps
```

## Setup

1. **Connect to cluster:**
```bash
gcloud container clusters get-credentials dev-cluster --zone=us-west2-a --project=development-690488
```

2. **Apply ApplicationSet:**
```bash
kubectl apply -f applicationset.yaml
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

Just add a folder under `environments/dev/`:

```bash
mkdir -p environments/dev/my-app
# Add manifests
git commit && git push
```

ArgoCD auto-discovers and deploys it.