# Helm Charts + Values Per Cluster (DRY)

## ✅ Current Setup

**Structure:**
```
charts/sample-app/          # Helm chart (DRY - shared)
  Chart.yaml
  values.yaml              # Default values
  templates/
    deployment.yaml
    service.yaml

values/dev/sample-app.yaml     # Dev overrides (2 replicas, 128Mi)
values/staging/sample-app.yaml # Staging overrides (3 replicas, 256Mi)
```

**ApplicationSets:**
- `applicationset-dev.yaml` - Deploys to dev cluster
- `applicationset-staging.yaml` - For future staging cluster

## How It Works

1. **One Chart, Multiple Values:**
   - Helm chart in `charts/sample-app/`
   - Dev values: `values/dev/sample-app.yaml`
   - Staging values: `values/staging/sample-app.yaml`

2. **ApplicationSet Matrix Generator:**
```yaml
generators:
- matrix:
    generators:
    - list:
        elements:
        - app: sample-app
    - list:
        elements:
        - cluster: dev
```

This creates Application `dev-sample-app` using `charts/sample-app` with `values/dev/sample-app.yaml`.

3. **ArgoCD Auto-Syncs:**
   - Push to GitHub → ArgoCD detects changes → deploys automatically
   - Prune + self-heal enabled

## Current Deployment

```bash
kubectl get applications -n argocd
# NAME             SYNC STATUS   HEALTH STATUS
# dev-sample-app   Synced        Healthy

kubectl get pods -n sample-app
# 2 nginx pods running (from values/dev/sample-app.yaml)
```

## Add New App

1. **Create Helm chart:**
```bash
mkdir -p charts/my-app/templates
```

2. **Create Chart.yaml:**
```yaml
apiVersion: v2
name: my-app
version: 1.0.0
```

3. **Create templates/** (deployment.yaml, service.yaml, etc.)

4. **Create values per cluster:**
```bash
# Dev
cat > values/dev/my-app.yaml <<EOF
replicaCount: 2
image:
  repository: myapp
  tag: latest
resources:
  limits:
    memory: 128Mi
EOF

# Staging
cat > values/staging/my-app.yaml <<EOF
replicaCount: 3
image:
  repository: myapp
  tag: stable
resources:
  limits:
    memory: 256Mi
EOF
```

5. **Update ApplicationSets:**

Add to `applicationset-dev.yaml`:
```yaml
- list:
    elements:
    - app: sample-app
    - app: my-app      # ← Add this
```

Add to `applicationset-staging.yaml` (same)

6. **Deploy:**
```bash
git add . && git commit -m "Add my-app" && git push
kubectl apply -f applicationset-dev.yaml
```

Done! ArgoCD creates `dev-my-app` automatically.

## Staging Cluster (Future)

When staging cluster is ready:

1. Get staging cluster API URL:
```bash
kubectl cluster-info | grep "Kubernetes control plane"
```

2. Update `applicationset-staging.yaml`:
```yaml
destination:
  server: https://<staging-cluster-url>
```

3. Apply to staging cluster:
```bash
kubectl apply -f applicationset-staging.yaml
```

All apps with `values/staging/*.yaml` auto-deploy to staging.

## Benefits

✅ **DRY:** Single chart, multiple environments  
✅ **Type-safe:** Helm validates YAML  
✅ **Version control:** All config in Git  
✅ **Auto-sync:** Push = deploy  
✅ **Easy diff:** Compare `values/dev/` vs `values/staging/`  

## Alternative: Auto-Discovery

To avoid manually listing apps in ApplicationSet, you could:
1. Use git directory generator scanning `charts/*/`
2. Combine with cluster list
3. Trade-off: More complex templating

Current approach is explicit and clear.

