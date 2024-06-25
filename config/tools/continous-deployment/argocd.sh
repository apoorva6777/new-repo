#!/bin/bash
echo "Starting ArgoCD deployments"
echo "Creating namespace for ArgoCD"
kubectl create namespace argocd
 
echo "Adding Helm repo for ArgoCD"
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

echo "Installing ArgoCD base components"
helm install argocd argo/argo-cd -n argocd --create-namespace -f ../tools/continous-deployment/values.yaml

echo "Exposing ArgoCD service using a Load Balancer on port 8080"
kubectl apply -f ../tools/continous-deployment/argocd-service.yaml

NAMESPACE="argocd"
SERVICE_NAME="argocd-lb"
MAX_RETRIES=120 
RETRY_INTERVAL=10 
retries=0
while true; do
    external_ip=$(kubectl get svc "$SERVICE_NAME" -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    if [[ -n "$external_ip" ]]; then
        break
    else
        retries=$((retries+1))
        if [[ $retries -eq $MAX_RETRIES ]]; then
            echo "Maximum retries reached. Failed to get external IP for $SERVICE_NAME."
            exit 1
        fi
        echo "Waiting for external IP assignment (retry $retries/$MAX_RETRIES)..."
        sleep "$RETRY_INTERVAL"
    fi
done

ARGOCD_EXTERNAL_IP="$external_ip"
admin_password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
ARGOCD_PASSWORD="$admin_password"

