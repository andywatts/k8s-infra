# Kong Infrastructure Considerations

Infrastructure changes and considerations for deploying Kong API Gateway to GKE.

## 🏗️ Current GKE Setup

From `/infra/gcp/projects/dev/gke.tf`:

```
- Cluster: dev-cluster
- Location: us-west2-a
- Node pool: primary-pool
- Machine type: e2-small
- Node count: 1
- Disk: 20GB
```

## ⚠️ Infrastructure Requirements for Kong

### 1. LoadBalancer Service

Kong creates a LoadBalancer service for the proxy. This requires:

**GCP External IP Quota:**
- Dev: 1 external IP
- Staging: 1 external IP
- Production: 1+ external IPs (or use Cloud Load Balancer)

**Check current quota:**
```bash
gcloud compute project-info describe \
  --project=development-690488 \
  | grep -A 2 EXTERNAL_IPS
```

**Increase if needed:**
```bash
# Request quota increase via GCP Console
# Compute Engine > Quotas > External IP addresses
```

### 2. Node Resources

**Current: e2-small (2 vCPU, 2GB RAM)**

With Kong added to dev cluster:
- Kong Gateway: 100-300m CPU, 128-256Mi RAM
- Kong Ingress Controller: 50-100m CPU, 64-128Mi RAM  
- sample-app: 2 pods × 100m CPU, 128Mi RAM
- ArgoCD: ~500m CPU, ~1Gi RAM

**Recommendation:**
✅ **Dev cluster**: Current e2-small nodes are sufficient with 1-2 nodes
⚠️ **Staging**: Consider e2-medium (2 vCPU, 4GB RAM) for better performance

### 3. Node Pool Scaling

**Current:** Fixed 1 node

**Recommended for Production/Staging:**
```hcl
# In gke.tf
resource "google_container_node_pool" "primary" {
  autoscaling {
    min_node_count = 2
    max_node_count = 5
  }
}
```

### 4. Firewall Rules

GKE automatically creates firewall rules for LoadBalancer services. Verify:

```bash
# List firewall rules
gcloud compute firewall-rules list \
  --project=development-690488 \
  | grep gke-dev-cluster

# Should see rules allowing traffic to NodePorts
```

If needed, create explicit rules:

```bash
# Allow HTTP/HTTPS to Kong
gcloud compute firewall-rules create allow-kong-http \
  --project=development-690488 \
  --direction=INGRESS \
  --priority=1000 \
  --network=default \
  --action=ALLOW \
  --rules=tcp:80,tcp:443 \
  --source-ranges=0.0.0.0/0 \
  --target-tags=gke-dev-cluster
```

### 5. Cloud Armor (Optional)

For production, consider adding Cloud Armor for DDoS protection:

```hcl
# In Terraform
resource "google_compute_security_policy" "kong_policy" {
  name = "kong-security-policy"

  rule {
    action   = "rate_based_ban"
    priority = "1000"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(429)"
      enforce_on_key = "IP"
      rate_limit_threshold {
        count        = 100
        interval_sec = 60
      }
    }
  }
}
```

## 📋 Terraform Updates Needed

### Option 1: Minimal (Dev Only)

No Terraform changes needed! Current setup works for dev:
- 1 node is sufficient
- LoadBalancer will be automatically provisioned
- External IP quota likely available

### Option 2: Production-Ready (Staging/Prod)

**File: `/infra/gcp/projects/staging/gke.tf`** (when created)

```hcl
resource "google_container_cluster" "staging" {
  name     = "staging-cluster"
  location = "${local.region}-a"

  initial_node_count       = 2
  remove_default_node_pool = true

  # Enable Workload Identity for better security
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Network policy for pod-to-pod security
  network_policy {
    enabled = true
  }

  deletion_protection = true  # Protect prod clusters
}

resource "google_container_node_pool" "staging" {
  name       = "primary-pool"
  location   = google_container_cluster.staging.location
  cluster    = google_container_cluster.staging.name

  # Autoscaling for Kong + apps
  autoscaling {
    min_node_count = 2
    max_node_count = 5
  }

  node_config {
    machine_type = "e2-medium"  # 2 vCPU, 4GB RAM
    disk_size_gb = 30

    # Enable preemptible for cost savings (optional)
    preemptible  = false

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    # Labels for cost tracking
    labels = {
      environment = "staging"
      managed-by  = "terraform"
    }

    # Taints for dedicated workloads (optional)
    # taint {
    #   key    = "workload"
    #   value  = "kong"
    #   effect = "NO_SCHEDULE"
    # }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}

# Reserve static external IP for Kong
resource "google_compute_address" "kong_staging" {
  name   = "kong-staging-ip"
  region = local.region
}

# Output the IP for reference
output "kong_staging_ip" {
  value = google_compute_address.kong_staging.address
}
```

### Option 3: Regional Cluster (High Availability)

For true HA, use regional clusters (multi-zone):

```hcl
resource "google_container_cluster" "prod" {
  name     = "prod-cluster"
  location = local.region  # Regional, not zonal

  initial_node_count       = 1  # Per zone
  remove_default_node_pool = true
}

resource "google_container_node_pool" "prod" {
  name     = "primary-pool"
  location = google_container_cluster.prod.location
  cluster  = google_container_cluster.prod.name

  # 2-5 nodes per zone × 3 zones = 6-15 total nodes
  autoscaling {
    min_node_count = 2
    max_node_count = 5
  }

  node_config {
    machine_type = "e2-standard-2"  # 2 vCPU, 8GB RAM
    disk_size_gb = 50
  }
}
```

## 💰 Cost Implications

### Dev Environment (Current)
- **Compute**: 1 × e2-small = ~$13/month
- **LoadBalancer**: ~$18/month
- **External IP**: ~$3/month
- **Total**: ~$34/month

### Staging (Recommended)
- **Compute**: 2 × e2-medium = ~$60/month
- **LoadBalancer**: ~$18/month
- **External IP**: ~$3/month
- **Total**: ~$81/month

### Production (Regional HA)
- **Compute**: 6 × e2-standard-2 = ~$360/month
- **LoadBalancer**: ~$18/month
- **External IP (static)**: ~$3/month
- **Total**: ~$381/month

## 🎯 Recommended Actions

### For Dev (Immediate)

✅ **No Terraform changes needed**
- Current setup sufficient for development
- Deploy Kong and test

### For Staging (Future)

1. **Create staging cluster Terraform**:
   - Copy `dev/gke.tf` to `staging/gke.tf`
   - Increase node count to 2
   - Enable autoscaling (2-5 nodes)
   - Use e2-medium instances

2. **Reserve static IP**:
   ```hcl
   resource "google_compute_address" "kong_staging" {
     name = "kong-staging-ip"
   }
   ```

3. **Update Kong staging values** to use reserved IP:
   ```yaml
   proxy:
     annotations:
       cloud.google.com/load-balancer-type: "External"
       # Reference the reserved IP
   ```

### For Production (Future)

1. **Regional cluster** for true HA
2. **Dedicated node pool** for Kong (optional)
3. **Cloud Armor** for DDoS protection
4. **Cloud CDN** for static content
5. **Binary Authorization** for secure deployments
6. **VPC-native networking** with private nodes

## 🔍 Monitoring & Alerting

Consider adding:

1. **GCP Monitoring**:
   - LoadBalancer health checks
   - Node CPU/memory utilization
   - Kong request rates

2. **Prometheus + Grafana**:
   - Kong metrics endpoint
   - Custom dashboards
   - Alert rules

3. **Logging**:
   - Kong access logs → Cloud Logging
   - Structured JSON logs
   - Log-based metrics

## 📝 Deployment Checklist

Before deploying Kong to production:

- [ ] External IP quota available
- [ ] Node resources adequate (CPU, memory)
- [ ] Firewall rules configured (if needed)
- [ ] LoadBalancer service working
- [ ] DNS records ready for custom domains
- [ ] TLS certificates prepared (cert-manager)
- [ ] Monitoring/alerting configured
- [ ] Backup strategy for Kong config
- [ ] Runbook for common issues
- [ ] Load testing completed

## 🚀 Getting Started

For dev cluster (no infrastructure changes needed):

```bash
# 1. Deploy Kong via ArgoCD
git add charts/kong/ values/dev/kong.yaml applicationset-dev.yaml
git commit -m "Add Kong API Gateway"
git push

# 2. Apply to cluster
kubectl apply -f applicationset-dev.yaml

# 3. Wait for LoadBalancer IP
kubectl get svc -n kong -w

# 4. Test Kong
KONG_IP=$(kubectl get svc -n kong kong-kong-proxy -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl http://$KONG_IP
```

That's it! No Terraform changes needed for dev.

