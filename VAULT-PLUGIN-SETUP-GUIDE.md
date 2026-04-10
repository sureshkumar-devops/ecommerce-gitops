# Vault Plugin Setup - Next Steps Guide

## Current Status ✅
You have already completed:
1. ✅ Created `argocd-cmp-cm` ConfigMap with Vault plugin configuration
2. ✅ Set up `argocd-repo-server-patch.yaml` to download the avp (argocd-vault-plugin) binary
3. ✅ Configured ConfigManagementPlugin (CMP) discovery and generate commands

---

## Next Steps (Step-by-Step)

### **STEP 1: Configure Vault Authentication for ArgoCD**
**What it does:** Allows ArgoCD's repo-server to authenticate with Vault and retrieve secrets

#### Option A: Using Kubernetes Service Account (Recommended for K8s)
```yaml
# File: k8s/argocd-vault-auth.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: argocd-repo-server
  namespace: argocd
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: argocd-vault
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list"]
- apiGroups: [""]
  resources: ["serviceaccounts"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: argocd-vault
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: argocd-vault
subjects:
- kind: ServiceAccount
  name: argocd-repo-server
  namespace: argocd
```

#### Option B: Using JWT Token Authentication
```yaml
# File: k8s/argocd-vault-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: argocd-vault-credentials
  namespace: argocd
type: Opaque
stringData:
  VAULT_ADDR: "https://vault.example.com:8200"
  VAULT_TOKEN: "s.xxxxxxxxxxxx"  # Replace with your token
  VAULT_SKIP_VERIFY: "false"
```

---

### **STEP 2: Patch the argocd-repo-server Pod**
**What it does:** Injects environment variables and mounts the ConfigMap for the repo-server to use

#### Update your patch with environment variables:
```yaml
# File: k8s/argocd-repo-server-patch.yaml (Update)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: argocd-repo-server
  namespace: argocd
spec:
  template:
    spec:
      serviceAccountName: argocd-repo-server  # Add this line
      
      volumes:
        - name: custom-tools
          emptyDir: {}
        - name: cmp-server
          configMap:
            name: argocd-cmp-cm
 
      initContainers:
        - name: download-avp
          image: alpine:3.19
          command: [sh, -c]
          args:
            - >
              wget -O /custom-tools/argocd-vault-plugin
              https://github.com/argoproj-labs/argocd-vault-plugin/releases/download/v1.18.0/argocd-vault-plugin_1.18.0_linux_amd64 &&
              chmod +x /custom-tools/argocd-vault-plugin
          volumeMounts:
            - name: custom-tools
              mountPath: /custom-tools
        
      containers:
        - name: repo-server
          env:
            - name: VAULT_ADDR
              valueFrom:
                secretKeyRef:
                  name: argocd-vault-credentials
                  key: VAULT_ADDR
            - name: VAULT_TOKEN
              valueFrom:
                secretKeyRef:
                  name: argocd-vault-credentials
                  key: VAULT_TOKEN
            - name: VAULT_SKIP_VERIFY
              valueFrom:
                secretKeyRef:
                  name: argocd-vault-credentials
                  key: VAULT_SKIP_VERIFY
                  
          volumeMounts:
            - name: custom-tools
              mountPath: /usr/local/bin/argocd-vault-plugin
              subPath: argocd-vault-plugin
            - name: cmp-server
              mountPath: /home/argocd/cmp-server/plugins
```
        

---

### **STEP 3: Apply Kubernetes Manifests**
**What it does:** Deploys all authentication and configuration to your cluster

```bash
# Apply Vault authentication setup
kubectl apply -f k8s/argocd-vault-auth.yaml
kubectl apply -f k8s/argocd-vault-secret.yaml

# Apply the repo-server patch (using kustomize or direct patch)
kubectl patch deployment argocd-repo-server -n argocd --patch-file k8s/argocd-repo-server-patch.yaml

# Verify the patch was applied
kubectl describe deployment argocd-repo-server -n argocd
kubectl logs deployment/argocd-repo-server -n argocd
```

---

### **STEP 4: Create Secrets in Vault**
**What it does:** Stores your secrets in Vault for ArgoCD to retrieve

Example Vault path structure:
```bash
# Login to Vault
vault login

# Create secrets for database credentials
vault kv put secret/ecommerce/prod/database \
  username="dbuser" \
  password="securepassword"

# Create secrets for API keys
vault kv put secret/ecommerce/prod/api \
  jwt_secret="your-jwt-secret" \
  api_key="your-api-key"

# Verify secrets
vault kv get secret/ecommerce/prod/database
```

---

### **STEP 5: Create Kubernetes Manifests with Vault References**
**What it does:** Templates that reference Vault secrets using argocd-vault-plugin placeholders

```yaml
# File: charts/my-app/templates/secrets.yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
  namespace: {{ .Values.namespace }}
type: Opaque
stringData:
  # Vault secret reference format: <path>:<key>
  DB_USERNAME: <path:secret/data/ecommerce/prod/database#username>
  DB_PASSWORD: <path:secret/data/ecommerce/prod/database#password>
  JWT_SECRET: <path:secret/data/ecommerce/prod/api#jwt_secret>
  API_KEY: <path:secret/data/ecommerce/prod/api#api_key>
```

---

### **STEP 6: Create or Update ArgoCD Application**
**What it does:** Tells ArgoCD to use the Vault plugin for secret injection

```yaml
# File: argocd/app-with-vault.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ecommerce-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/sureshkumar-devops/ecommerce-gitops
    targetRevision: dev
    path: charts/my-app
    
    # KEY CONFIGURATION - Enable Vault plugin
    plugin:
      name: argocd-vault-plugin
    
    helm:
      values: |
        namespace: ecommerce
        environment: prod
        
  destination:
    server: https://kubernetes.default.svc
    namespace: ecommerce
    
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

---

### **STEP 7: Test the Setup**
**What it does:** Verifies that the plugin is working correctly

```bash
# 1. Check if the plugin is recognized
kubectl get ApplicationSets -n argocd

# 2. Sync the application manually
argocd app sync ecommerce-app

# 3. Check deployment status
kubectl get secret app-secrets -n ecommerce -o yaml
# Should show decoded values from Vault

# 4. Check repo-server logs for any errors
kubectl logs deployment/argocd-repo-server -n argocd --tail=50

# 5. Verify secrets are created with actual values (NOT placeholders)
kubectl get secret app-secrets -n ecommerce
```

---

## Complete Workflow Summary

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Configure Vault Authentication (ServiceAccount/JWT)      │
│    └─> Create: argocd-vault-auth.yaml, argocd-vault-secret  │
├─────────────────────────────────────────────────────────────┤
│ 2. Update ArgoCD Repo-Server (Add env vars & mounts)        │
│    └─> Update: argocd-repo-server-patch.yaml                │
├─────────────────────────────────────────────────────────────┤
│ 3. Apply Manifests to Cluster                               │
│    └─> kubectl apply all YAML files                         │
├─────────────────────────────────────────────────────────────┤
│ 4. Create Secrets in Vault                                  │
│    └─> vault kv put secret/path/key value                   │
├─────────────────────────────────────────────────────────────┤
│ 5. Create Kubernetes Manifests with Vault References        │
│    └─> Use <path:secret/data/path#key> format               │
├─────────────────────────────────────────────────────────────┤
│ 6. Create/Update ArgoCD Application                         │
│    └─> Set plugin: argocd-vault-plugin in source.plugin     │
├─────────────────────────────────────────────────────────────┤
│ 7. Test & Verify                                            │
│    └─> Check logs, verify secrets are created correctly     │
└─────────────────────────────────────────────────────────────┘
```

---

## Troubleshooting

### Plugin Not Recognized
```bash
# Check if CMP ConfigMap is mounted
kubectl exec -it deployment/argocd-repo-server -n argocd -- ls -la /home/argocd/cmp-server/plugins

# Check if avp binary is present
kubectl exec -it deployment/argocd-repo-server -n argocd -- which argocd-vault-plugin
```

### Authentication Failures
```bash
# Check Vault connectivity
kubectl exec -it deployment/argocd-repo-server -n argocd -- \
  curl -k https://vault.example.com:8200/v1/sys/health

# Verify environment variables
kubectl exec -it deployment/argocd-repo-server -n argocd -- env | grep VAULT
```

### Secrets Not Being Replaced
```bash
# Verify the placeholder format in your manifests
# Correct format: <path:secret/data/ecommerce/prod/database#username>
# Wrong format: <path:secret/ecommerce/prod/database#username>

# Enable debug logging (if available in your version)
```

---

## Key Concepts Explained

**ConfigManagementPlugin (CMP):** A plugin system in ArgoCD that allows custom templating/generation tools
**argocd-vault-plugin (avp):** A lightweight tool that replaces Vault secret references in manifests
**Secret Placeholder:** Format `<path:VAULT_PATH#KEY>` that the plugin detects and replaces
**Service Account:** Kubernetes identity used by ArgoCD repo-server to authenticate with Vault
