# ✅ Setup Complete

## What's Running

**GitHub Repo:** https://github.com/andywatts/k8s-apps (public)

**ApplicationSet:** Monitors `environments/dev/*` and auto-deploys

**Sample App:** 2 nginx pods running in `sample-app` namespace

```bash
kubectl get pods -n sample-app
kubectl get svc -n sample-app
```

## How It Works

**1. ApplicationSet Generator**
```yaml
generators:
  - git:
      repoURL: https://github.com/andywatts/k8s-apps
      directories:
      - path: environments/dev/*
```

This scans the repo for directories matching `environments/dev/*` and creates an ArgoCD Application for each.

**2. Auto-Discovery**

When you add a new app:
```bash
mkdir -p environments/dev/my-new-app
# Add deployment.yaml, service.yaml, etc.
git commit && git push
```

ArgoCD detects it within ~3 minutes and deploys automatically.

**3. Current Structure**

```
k8s-apps/
├── applicationset.yaml          # Auto-discovery config
└── environments/
    └── dev/
        └── sample-app/          # ← Deployed as "dev-sample-app"
            ├── deployment.yaml
            └── service.yaml
```

## Deploy Another App

```bash
cd /Users/andywatts/Code/infra/k8s-apps

# Create new app
mkdir -p environments/dev/hello-world
cat > environments/dev/hello-world/deployment.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-world
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hello-world
  template:
    metadata:
      labels:
        app: hello-world
    spec:
      containers:
      - name: app
        image: nginxdemos/hello
        ports:
        - containerPort: 80
EOF

git add . && git commit -m "Add hello-world app" && git push
```

Wait ~3 min, then:
```bash
kubectl get applications -n argocd
kubectl get pods -n hello-world
```

## Access ArgoCD UI

```bash
# Get password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port forward
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Open https://localhost:8080 (login: admin)

