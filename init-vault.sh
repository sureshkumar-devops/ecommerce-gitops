#!/bin/bash

# Vault Initialization Script for ArgoCD Integration
# Run this after deploying Vault

set -e

echo "🔍 Checking Vault status..."
kubectl wait --for=condition=ready pod -l app=vault -n vault --timeout=300s

echo "🚀 Initializing Vault..."
INIT_RESPONSE=$(kubectl exec -n vault vault-0 -- vault operator init -format=json)

# Extract keys and root token
VAULT_KEYS=$(echo "$INIT_RESPONSE" | jq -r '.unseal_keys_b64[]')
VAULT_TOKEN=$(echo "$INIT_RESPONSE" | jq -r '.root_token')

echo "🔑 Unsealing Vault..."
for key in $VAULT_KEYS; do
    kubectl exec -n vault vault-0 -- vault operator unseal "$key"
done

echo "📝 Saving credentials..."
echo "VAULT_TOKEN: $VAULT_TOKEN" > vault-credentials.txt
echo "VAULT_ADDR: http://vault.vault.svc.cluster.local:8200" >> vault-credentials.txt

echo "🔐 Enabling KV secrets engine..."
kubectl exec -n vault vault-0 -- vault secrets enable -path=secret kv-v2

echo "📋 Creating ArgoCD policy..."
kubectl exec -n vault vault-0 -- vault policy write argocd-policy - <<EOF
path "secret/data/ecommerce/*" {
  capabilities = ["read", "list"]
}
path "secret/metadata/ecommerce/*" {
  capabilities = ["list"]
}
EOF

echo "🎫 Creating ArgoCD token..."
ARGOCD_TOKEN=$(kubectl exec -n vault vault-0 -- vault token create -policy=argocd-policy -ttl=8760h -format=json | jq -r '.auth.client_token')

echo "ARGOCD_TOKEN: $ARGOCD_TOKEN" >> vault-credentials.txt

echo "✅ Vault initialized successfully!"
echo ""
echo "📋 IMPORTANT: Update your argocd-vault-secret.yaml with this token:"
echo "VAULT_TOKEN: $ARGOCD_TOKEN"
echo ""
echo "🔐 Credentials saved to: vault-credentials.txt"
echo ""
echo "🧪 Test Vault:"
echo "export VAULT_ADDR=http://vault.vault.svc.cluster.local:8200"
echo "export VAULT_TOKEN=$ARGOCD_TOKEN"
echo "vault kv list secret/"