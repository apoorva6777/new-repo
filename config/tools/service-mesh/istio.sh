#!/bin/bash
echo "downloading istioctl"
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.22.0 sh -
cd istio-1.22.0
echo "setting istioctl profile"
export PATH=$PWD/bin:$PATH

echo "Getting gateway API CRD's"
kubectl get crd gateways.gateway.networking.k8s.io &> /dev/null || \
  { kubectl kustomize "github.com/kubernetes-sigs/gateway-api/config/crd/experimental?ref=v1.1.0" | kubectl apply -f -; }

echo "Getting ambient mode"
istioctl install --set profile=ambient --skip-confirmation
kubectl get pods,daemonset -n istio-system
kubectl create namespace istio-ingress
cd ..
istioctl install -f ../tools/service-mesh/ingress.yaml --skip-confirmation


# Reading namespace names from JSON environment variable
namespaces=$(echo "$NAMESPACE_JSON" | jq -r '.[]')

for ns in $namespaces; do
    echo "Processing namespace: $ns"
    
    # Creating namespace
    kubectl create ns "$ns"
    
    # Labeling namespace
    kubectl label namespace "$ns" istio.io/dataplane-mode=ambient
    
    # Applying Istio Waypoint 
    istioctl x waypoint apply --enroll-namespace -n "$ns" --wait
done

sleep 30

# Fetching IP of CLB for istio-ingressgateway
NAMESPACE="istio-ingress"
SERVICE_NAME="istio-ingressgateway"
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

ISTIO_EXTERNAL_IP="$external_ip"
echo "Istio is accessible on http://$ISTIO_EXTERNAL_IP"
