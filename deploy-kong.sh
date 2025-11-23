#!/bin/bash
set -e

# Kong Deployment Script
# Deploys Kong API Gateway to GKE via ArgoCD

CLUSTER=${1:-dev}
PROJECT_ID="development-690488"
REGION="us-west2"
ZONE="${REGION}-a"

echo "🚀 Deploying Kong to ${CLUSTER} cluster"

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Step 1: Connect to cluster
echo -e "${YELLOW}Step 1: Connecting to cluster...${NC}"
gcloud container clusters get-credentials ${CLUSTER}-cluster \
  --zone=${ZONE} \
  --project=${PROJECT_ID}

# Step 2: Verify ArgoCD is running
echo -e "${YELLOW}Step 2: Verifying ArgoCD...${NC}"
if kubectl get namespace argocd &> /dev/null; then
  echo -e "${GREEN}✓ ArgoCD namespace found${NC}"
else
  echo "❌ ArgoCD not found. Please install ArgoCD first."
  exit 1
fi

# Step 3: Apply ApplicationSet
echo -e "${YELLOW}Step 3: Applying ApplicationSet...${NC}"
kubectl apply -f applicationset-${CLUSTER}.yaml

# Step 4: Wait for Kong application to be created
echo -e "${YELLOW}Step 4: Waiting for Kong application...${NC}"
for i in {1..30}; do
  if kubectl get application ${CLUSTER}-kong -n argocd &> /dev/null; then
    echo -e "${GREEN}✓ Kong application created${NC}"
    break
  fi
  echo "Waiting for application creation... ($i/30)"
  sleep 2
done

# Step 5: Wait for Kong namespace
echo -e "${YELLOW}Step 5: Waiting for Kong namespace...${NC}"
for i in {1..30}; do
  if kubectl get namespace kong &> /dev/null; then
    echo -e "${GREEN}✓ Kong namespace created${NC}"
    break
  fi
  echo "Waiting for namespace... ($i/30)"
  sleep 2
done

# Step 6: Watch Kong deployment
echo -e "${YELLOW}Step 6: Monitoring Kong deployment...${NC}"
echo "This may take 2-3 minutes..."
kubectl wait --for=condition=available --timeout=300s \
  deployment/kong-kong -n kong 2>/dev/null || true

# Step 7: Get Kong service info
echo -e "\n${YELLOW}Step 7: Kong Service Information${NC}"
echo "Waiting for LoadBalancer IP..."
for i in {1..60}; do
  KONG_IP=$(kubectl get svc kong-kong-proxy -n kong \
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
  
  if [ ! -z "$KONG_IP" ]; then
    echo -e "${GREEN}✓ Kong is ready!${NC}"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🎉 Kong API Gateway Deployed Successfully"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📍 Proxy LoadBalancer IP: ${KONG_IP}"
    echo ""
    echo "🔍 Quick Test:"
    echo "  curl http://${KONG_IP}"
    echo ""
    echo "🎛️  Access Admin API (port-forward):"
    echo "  kubectl port-forward -n kong svc/kong-kong-admin 8001:8001"
    echo "  curl http://localhost:8001/"
    echo ""
    echo "🖥️  Access Manager GUI (port-forward):"
    echo "  kubectl port-forward -n kong svc/kong-kong-manager 8002:8002"
    echo "  open http://localhost:8002"
    echo ""
    echo "📊 Check Kong Status:"
    echo "  kubectl get pods -n kong"
    echo "  kubectl get svc -n kong"
    echo ""
    echo "📖 Documentation:"
    echo "  See KONG.md for full usage guide"
    echo ""
    break
  fi
  
  if [ $i -eq 60 ]; then
    echo "⚠️  LoadBalancer IP not assigned yet. Check with:"
    echo "  kubectl get svc -n kong -w"
  else
    echo "Waiting for LoadBalancer IP... ($i/60)"
    sleep 3
  fi
done

# Step 8: Show ArgoCD app status
echo -e "${YELLOW}ArgoCD Application Status:${NC}"
kubectl get application ${CLUSTER}-kong -n argocd

echo ""
echo -e "${GREEN}✓ Deployment complete!${NC}"

