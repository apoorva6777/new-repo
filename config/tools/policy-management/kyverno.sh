#!/bin/bash

echo "Starting Kyverno deployments"
echo "Adding Helm repo for Kyverno"
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update

echo "Installing Kyverno Core Components"
helm install kyverno kyverno/kyverno -n kyverno --create-namespace \
--set admissionController.replicas=3 \
--set backgroundController.replicas=2 \
--set cleanupController.replicas=2 \
--set reportsController.replicas=2

sleep 30
echo "Kyverno Installation done."

# Applying policy to disallow deployments in the default namespace
echo "Creating a cluster policy using Kyverno to disallow deployments in the default namespace"
kubectl apply -f ../tools/policy-management/kyverno-disallow-default-namespace-policy.yaml
echo "Policy Applied"
echo "Kyverno setup complete"
