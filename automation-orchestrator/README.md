# Automation Orchestrator for Ansible Automation Platform

One-command deployment of Ansible Automation Platform's Automation Orchestrator using ArgoCD.

## Quick Start

### Prerequisites

**1. Grant ArgoCD permissions (required once per namespace):**

```bash
# Replace 'ao-demo' with your desired namespace
oc adm policy add-role-to-user admin \
  system:serviceaccount:openshift-gitops:openshift-gitops-argocd-application-controller \
  -n ao-demo
```

**2. Verify permissions:**

```bash
# Should return "yes"
oc auth can-i create secrets \
  --as=system:serviceaccount:openshift-gitops:openshift-gitops-argocd-application-controller \
  -n ao-demo
```

### Deploy

```bash
# Deploy Automation Orchestrator with PostgreSQL
oc apply -f https://raw.githubusercontent.com/BBGrimmett2/gitops-catalog/automation-orchestrator/automation-orchestrator-argocd-app.yaml
```

**That's it!** ArgoCD will automatically:
1. Create the namespace
2. Deploy PostgreSQL 15 with 3 databases
3. Install the Automation Orchestrator operator
4. Deploy all Automation Orchestrator components
5. Create routes for UI access

### Monitor Deployment

```bash
# Watch deployment progress
oc get pods -n ao-demo -w

# Check overall status (wait for READY=True)
oc get automationorchestrator automation-orchestrator -n ao-demo
```

### Access

```bash
# Get UI URL
oc get route automation-orchestrator -n ao-demo

# Get admin password
oc get secret automation-orchestrator-initial-admin-password -n ao-demo \
  -o jsonpath='{.data.password}' | base64 -d && echo
```

## What Gets Deployed

**All components deploy to a single namespace (default: `ao-demo`):**

- PostgreSQL 15 (3 databases: orchestrator, temporal, temporal_visibility)
- Automation Orchestrator Operator
- Automation Orchestrator components:
  - Backend API (2 replicas)
  - Background Worker
  - Worker  
  - UI
  - Temporal Server
  - Redis Cache

**Resources:** ~8 pods, 1 route, 2-3 GB memory, 1-2 CPU cores

## Default Credentials (POC/Demo)

**PostgreSQL:**
- Password: `RedHat123`

**Admin User:**
- Password: See secret `automation-orchestrator-initial-admin-password`

**⚠️ WARNING:** These are placeholder credentials for POC/demo only. For production, update secrets before deploying.

## Custom Namespace

To deploy to a different namespace:

1. **Edit the ArgoCD application:**
   ```bash
   # Download and edit
   curl -o ao-app.yaml https://raw.githubusercontent.com/BBGrimmett2/gitops-catalog/automation-orchestrator/automation-orchestrator-argocd-app.yaml
   
   # Change destination.namespace from 'ao-demo' to your namespace
   sed -i 's/namespace: ao-demo/namespace: my-namespace/g' ao-app.yaml
   ```

2. **Grant RBAC to your namespace:**
   ```bash
   oc adm policy add-role-to-user admin \
     system:serviceaccount:openshift-gitops:openshift-gitops-argocd-application-controller \
     -n my-namespace
   ```

3. **Apply:**
   ```bash
   oc apply -f ao-app.yaml
   ```

## Troubleshooting

### Permission Denied

**Error:** `secrets is forbidden` or `services is forbidden`

**Fix:** Grant RBAC permissions (see Prerequisites above)

```bash
oc adm policy add-role-to-user admin \
  system:serviceaccount:openshift-gitops:openshift-gitops-argocd-application-controller \
  -n ao-demo
```

### Deployment Stuck

**Check ArgoCD sync status:**
```bash
oc get application automation-orchestrator-demo -n openshift-gitops
```

**Check for errors:**
```bash
# ArgoCD logs
oc logs -n openshift-gitops -l app.kubernetes.io/name=argocd-application-controller --tail=50

# PostgreSQL init logs
oc logs -l job-name=postgresql-init-databases -n ao-demo

# Backend migration logs  
oc logs -l app.kubernetes.io/component=backend-migration -n ao-demo
```

### Clean Uninstall

```bash
# Delete ArgoCD application (will remove all resources)
oc delete application automation-orchestrator-demo -n openshift-gitops

# Delete namespace
oc delete namespace ao-demo
```

## Production Deployment

For production use:

1. **Update secrets** before deploying:
   - Generate strong passwords (32+ characters)
   - Use Vault, Sealed Secrets, or external secret management
   - Enable PostgreSQL SSL

2. **Customize resources:**
   - Fork this repository
   - Edit `automation-orchestrator/instance/overlays/argocd-demo/`
   - Update AutomationOrchestrator CR with production values
   - Update PostgreSQL storage class and size

3. **Update ArgoCD application:**
   - Point to your forked repository
   - Update `source.repoURL` and `source.targetRevision`

## Support

- **Product Support:** [Red Hat Customer Portal](https://access.redhat.com/support)
- **GitOps Catalog:** [GitHub Issues](https://github.com/redhat-cop/gitops-catalog/issues)
- **Documentation:** [Ansible Automation Platform Docs](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/)
