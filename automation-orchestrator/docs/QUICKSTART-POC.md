# Quick Start - POC/Lab Deployment

This guide shows how to deploy Automation Orchestrator for POC/Lab/Demo purposes in under 5 minutes.

**WARNING: This uses placeholder passwords (RedHat123) and is NOT suitable for production use.**

## Prerequisites

- OpenShift 4.12+ cluster with cluster-admin access
- `oc` CLI installed and logged in
- `aapctl` CLI installed
- Valid Red Hat subscription with access to Automation Orchestrator operator

## 2-Step Deployment

### Step 1: Install the Operator

```bash
oc apply -k https://github.com/redhat-cop/gitops-catalog/automation-orchestrator/operator/overlays/default?ref=main

# Wait for operator to be ready (takes 2-3 minutes)
oc wait --for=condition=ready pod \
  -l control-plane=controller-manager \
  -n automation-orchestrator \
  --timeout=10m
```

### Step 2: Deploy Complete Stack

```bash
# Clone the repo (or use your fork)
git clone https://github.com/redhat-cop/gitops-catalog.git
cd gitops-catalog/automation-orchestrator

# Generate the AutomationOrchestrator CR
./scripts/generate-ao-manifests.sh

# Deploy PostgreSQL + Instance with placeholder secrets
oc apply -k instance/overlays/with-postgres

# Monitor deployment
oc get pods -n automation-orchestrator -w
```

That's it! The deployment includes:
- PostgreSQL database (3 databases: orchestrator, temporal, temporal_visibility)
- Automation Orchestrator instance
- All required secrets (using placeholder password: RedHat123)

## Verify Deployment

Check all pods are running:

```bash
oc get pods -n automation-orchestrator

# Expected output:
# postgresql-0                          1/1     Running
# automation-orchestrator-api-*         1/1     Running
# automation-orchestrator-worker-*      1/1     Running
# automation-orchestrator-temporal-*    1/1     Running
# automation-orchestrator-ui-*          1/1     Running
```

Get the route:

```bash
oc get route -n automation-orchestrator

# Access the UI
echo "https://$(oc get route automation-orchestrator -n automation-orchestrator -o jsonpath='{.spec.host}')"
```

Get admin password:

```bash
oc get secret automation-orchestrator-admin-password \
  -n automation-orchestrator \
  -o jsonpath='{.data.password}' | base64 -d
echo
```

Login with username `admin` and the password from above.

## What Gets Deployed

### Resources Created

- **Namespace**: automation-orchestrator
- **PostgreSQL**: Single StatefulSet with 10Gi storage
  - Database: orchestrator (user: orchestrator, pass: RedHat123)
  - Database: temporal (user: temporal, pass: RedHat123)
  - Database: temporal_visibility (user: temporal, pass: RedHat123)
- **Automation Orchestrator**: Complete instance with all components
- **Secrets**: Pre-created with placeholder password

### Default Credentials

**Database Credentials** (POC/Lab only):
- Orchestrator DB: orchestrator / RedHat123
- Temporal DB: temporal / RedHat123
- PostgreSQL Admin: postgres / changeme

**UI Credentials**:
- Username: admin
- Password: Retrieved from auto-generated secret (see above)

## ArgoCD Deployment

Create an ArgoCD Application for automated deployment:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: automation-orchestrator-poc
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/redhat-cop/gitops-catalog.git
    targetRevision: main
    path: automation-orchestrator/instance/overlays/with-postgres
  destination:
    server: https://kubernetes.default.svc
  syncPolicy:
    automated:
      prune: false
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

## Customization

### Change Namespace

```bash
# Use the custom namespace component
mkdir -p instance/overlays/my-poc
cat > instance/overlays/my-poc/kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: ao-demo
components:
  - ../../components/custom-namespace
resources:
  - ../with-postgres
EOF

oc apply -k instance/overlays/my-poc
```

### Use External PostgreSQL

```bash
# Edit the secrets to point to your PostgreSQL
vim instance/overlays/default/secrets/orchestrator-pg-credentials.yaml
vim instance/overlays/default/secrets/temporal-pg-credentials.yaml

# Deploy without bundled PostgreSQL
oc apply -k instance/overlays/default
```

### Increase Storage

```bash
# Use custom storage overlay
vim postgresql/overlays/custom-storage/pvc-patch.yaml
# Change storage size to desired value

oc apply -k postgresql/overlays/custom-storage
```

## Cleanup

Remove everything:

```bash
# Delete instance
oc delete automationorchestrator automation-orchestrator -n automation-orchestrator

# Delete operator
oc delete subscription automation-orchestrator-operator -n automation-orchestrator
oc delete csv -n automation-orchestrator \
  -l operators.coreos.com/automation-orchestrator-operator.automation-orchestrator

# Delete PostgreSQL and PVC (removes all data)
oc delete statefulset postgresql -n automation-orchestrator
oc delete pvc postgresql-data-postgresql-0 -n automation-orchestrator

# Delete namespace
oc delete namespace automation-orchestrator
```

## Transitioning to Production

When you're ready to move from POC to production:

1. **Generate secure passwords**:
   ```bash
   cd automation-orchestrator
   rm instance/overlays/default/secrets/*.yaml
   ./scripts/generate-secrets.sh default
   ```

2. **Update PostgreSQL passwords**:
   - Use external managed PostgreSQL (recommended)
   - Or update postgresql/base/configmap-init.yaml with generated passwords

3. **Use custom storage**:
   ```bash
   oc apply -k postgresql/overlays/custom-storage
   ```

4. **Enable SSL/TLS** for PostgreSQL connections:
   - Set sslmode to "require" or "verify-full" in secrets
   - Create CA certificate secret if using verify-full

5. **Configure backups** for PostgreSQL

6. **Set resource limits** in the AutomationOrchestrator CR

7. **Review security** settings and RBAC

See [docs/complete-installation.md](complete-installation.md) for production deployment guide.

## Troubleshooting

### Pods Not Starting

Check events:
```bash
oc get events -n automation-orchestrator --sort-by='.lastTimestamp'
```

### Database Connection Errors

Verify PostgreSQL is ready:
```bash
oc exec postgresql-0 -n automation-orchestrator -- pg_isready -U postgres
```

Check database init job:
```bash
oc logs job/postgresql-init-databases -n automation-orchestrator
```

### Operator Not Installing

Check subscription:
```bash
oc get subscription -n automation-orchestrator
oc describe subscription automation-orchestrator-operator -n automation-orchestrator
```

Check catalog source:
```bash
oc get catalogsource -n openshift-marketplace
```

## Next Steps

- Explore the Automation Orchestrator UI
- Create your first EDA project
- Configure decision environments
- Set up event sources
- Review the full documentation: [README.md](../README.md)

## Support

For issues:
- **Product support**: Contact Red Hat Support
- **GitOps Catalog**: https://github.com/redhat-cop/gitops-catalog/issues
- **Documentation**: https://access.redhat.com/documentation/en-us/red_hat_ansible_automation_platform/
