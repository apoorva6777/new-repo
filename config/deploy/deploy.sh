#!/bin/bash

# Define default values
API_KEY=""
NAMESPACE_JSON='[]'
REGION="eu-central-1"
CLUSTER_NAME="dev_sensonic_eks_cluster"

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -k|--api-key)
            API_KEY="$2"
            shift 2
            ;;
        -n|--namespaces)
            NAMESPACE_JSON="$2"
            shift 2
            ;;
        -r|--region)
            REGION="$2"
            shift 2
            ;;
        -c|--cluster-name)
            CLUSTER_NAME="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1"
            exit 1
    esac
done

echo "API Key: $API_KEY"
echo "Namespace JSON: $NAMESPACE_JSON"
echo "Region: $REGION"
echo "Cluster Name: $CLUSTER_NAME"

echo "Connecting to Kubernetes cluster"
aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME"

sed -E "s|<CLUSTER_NAME>|$CLUSTER_NAME|g; " ../scripts/autoscaler.yaml > ../scripts/cluster-autoscaler.yaml

kubectl get svc
sleep 30
cd ..
cd scripts

echo "Deploying metrics server on cluster"
kubectl apply -f metric-server.yaml
sleep 30
echo "printing status of metric server"
kubectl -n kube-system get deployment/metrics-server
echo "cluster metric deployed"

echo "Deploying cluster autoscaler on cluster"
kubectl apply -f cluster-autoscaler.yaml
sleep 50
echo "Printing status of cluster autoscaler"
kubectl -n kube-system get cm cluster-autoscaler-status -oyaml    
echo "Cluster Autoscaler deployed"

cd ..
cd deploy

# ISTIO
echo "Moving to Istio folder"
source ../tools/service-mesh/istio.sh
echo "Istio setup Done"
sleep 30
echo "-------------------------------------------------------------------------------"

# KYVERNO
echo "Moving to Kyverno folder"
source ../tools/policy-management/kyverno.sh
echo "Kyverno setup Done"
echo "-------------------------------------------------------------------------------"

# ArgoCD
echo "Moving to ArgoCD folder"
source ../tools/continous-deployment/argocd.sh
echo "ArgoCD setup Done"
echo "The initial admin password is: $ARGOCD_PASSWORD"
echo "-------------------------------------------------------------------------------"

# FluentBit
sed "s/API_KEY_PLACEHOLDER/${API_KEY}/g" ../tools/log-management/values.yaml > ../tools/log-management/values-tmp.yaml
echo "Moving to Fluentbit folder"
source ../tools/log-management/fluent.sh
echo "Fluent-bit setup Done"
echo "-------------------------------------------------------------------------------"

echo "All setup done.."
echo "Printing out URL's and credentials"
echo "-------------------------------------------------------------------------------"
echo "for ArgoCD"
echo "ArgoCD accessible at http://$ARGOCD_EXTERNAL_IP:8080"
echo "The initial admin username is: admin"
echo "The initial admin password is: $ARGOCD_PASSWORD"
echo "-------------------------------------------------------------------------------"
echo "Microservices product page exposed at: http://$ISTIO_EXTERNAL_IP/"
echo "setup complete"
echo "done..."
