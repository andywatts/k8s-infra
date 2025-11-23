# k8s-apps

GitOps repo for Kubernetes applications managed by ArgoCD.

## Structure

```
charts/
  sample-app/          # Helm chart (DRY - shared across clusters)
    Chart.yaml
    values.yaml        # Default values
    templates/
values/
  dev/
    sample-app.yaml    # Dev cluster overrides
  staging/
    sample-app.yaml    # Staging cluster overrides
applicationset-dev.yaml      # Auto-discovers values/dev/*.yaml
applicationset-staging.yaml  # Auto-discovers values/staging/*.yaml
```

**DRY approach:** One Helm chart, multiple values files per cluster.

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

## Deploy New App

1. **Create Helm chart:**
```bash
mkdir -p charts/my-app/templates
# Add Chart.yaml, values.yaml, templates/
```

2. **Create values per cluster:**
```bash
cat > values/dev/my-app.yaml <<EOF
replicaCount: 2
image:
  repository: myapp
  tag: latest
EOF

cat > values/staging/my-app.yaml <<EOF
replicaCount: 3
image:
  repository: myapp
  tag: stable
EOF
```

3. **Deploy:**
```bash
git add . && git commit -m "Add my-app" && git push
```

ArgoCD discovers `values/dev/my-app.yaml` → deploys `charts/my-app` to dev with dev values.

## When Staging Cluster is Ready

1. Update `server` URL in `applicationset-staging.yaml`
2. Apply to staging cluster: `kubectl apply -f applicationset-staging.yaml`
3. Apps with `values/staging/*.yaml` auto-deploy to staging