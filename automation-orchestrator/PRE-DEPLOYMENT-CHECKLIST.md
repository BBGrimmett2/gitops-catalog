# Pre-Deployment Checklist

Use this checklist before deploying Automation Orchestrator to a cluster.

## Validation Complete

- [x] Directory structure created (40 files)
- [x] Kustomize builds validated (all overlays)
- [x] Placeholder secrets created
- [x] PostgreSQL configuration complete
- [x] AutomationOrchestrator CR created
- [x] ArgoCD sync waves configured
- [x] Documentation complete

## Pre-Deployment Tests

### 1. Local Validation (No Cluster Required)

Run these tests locally to verify manifests before deploying:

```bash
cd automation-orchestrator

# Test operator overlay
kustomize build operator/overlays/default > /dev/null
echo "Operator overlay: OK"

# Test PostgreSQL overlays
kustomize build postgresql/overlays/default > /dev/null
echo "PostgreSQL default overlay: OK"

kustomize build postgresql/overlays/custom-storage > /dev/null
echo "PostgreSQL custom-storage overlay: OK"

# Test instance overlays
kustomize build instance/overlays/default > /dev/null
echo "Instance default overlay: OK"

kustomize build instance/overlays/with-postgres > /dev/null
echo "Instance with-postgres overlay: OK"

# Or use the validation script
./scripts/validate-manifests.sh
```

### 2. Verify Resource Counts

```bash
# Complete stack should generate exactly 9 resources
kustomize build instance/overlays/with-postgres | grep "^kind:" | wc -l
# Expected: 9

# Resource breakdown
kustomize build instance/overlays/with-postgres | grep "^kind:" | sort | uniq -c
# Expected:
#    1 kind: AutomationOrchestrator
#    2 kind: ConfigMap
#    1 kind: Job
#    1 kind: Namespace
#    2 kind: Secret
#    1 kind: Service
#    1 kind: StatefulSet
```

### 3. Check AutomationOrchestrator CR

```bash
# Verify CR has all required fields
kustomize build instance/overlays/with-postgres | \
  grep -A50 "kind: AutomationOrchestrator" | \
  grep -E "(postgres:|temporal:|api:|worker:|ui:)" | wc -l
# Should be > 5 (all main sections present)
```

### 4. Verify Secrets

```bash
# Check secrets are included
kustomize build instance/overlays/with-postgres | \
  grep -A5 "kind: Secret" | \
  grep "password:" | grep "RedHat123"
# Should show placeholder passwords
```

### 5. Verify Sync Waves

```bash
# Check sync wave annotations
kustomize build instance/overlays/with-postgres | \
  grep "sync-wave" | sort | uniq -c
# Expected:
#    3 argocd.argoproj.io/sync-wave: "1" (Namespace, StatefulSet, Service, Secrets)
#    1 argocd.argoproj.io/sync-wave: "2" (Job)
#    1 argocd.argoproj.io/sync-wave: "3" (AutomationOrchestrator)
```

## Cluster Prerequisites

Before deploying to OpenShift:

- [ ] OpenShift 4.12+ cluster available
- [ ] Cluster admin access configured (`oc whoami` shows your user)
- [ ] Red Hat Operator Catalog accessible
- [ ] Sufficient cluster resources:
  - 4 vCPUs available
  - 8 GB RAM available
  - 20 GB storage available
- [ ] Default storage class configured (or custom storage class ready)

```bash
# Verify cluster access
oc whoami
oc cluster-info

# Check storage classes
oc get storageclass

# Check available resources
oc describe nodes | grep -A5 "Allocated resources"

# Verify Red Hat operators are available
oc get catalogsource -n openshift-marketplace | grep redhat
```

## Deployment Order

### Option 1: All-in-One (Fastest for POC)

```bash
# Prerequisites complete? Deploy everything:
oc apply -k automation-orchestrator/operator/overlays/default
# Wait 2-3 minutes for operator
oc wait --for=condition=ready pod -l control-plane=controller-manager \
  -n automation-orchestrator --timeout=10m
# Deploy instance
oc apply -k automation-orchestrator/instance/overlays/with-postgres
```

### Option 2: Staged Deployment (Safer)

```bash
# Step 1: Operator
oc apply -k automation-orchestrator/operator/overlays/default
oc wait --for=condition=ready pod -l control-plane=controller-manager \
  -n automation-orchestrator --timeout=10m

# Step 2: PostgreSQL
oc apply -k automation-orchestrator/postgresql/overlays/default
oc wait --for=condition=ready pod -l app=postgresql \
  -n automation-orchestrator --timeout=5m

# Step 3: Verify database init
oc wait --for=condition=complete job/postgresql-init-databases \
  -n automation-orchestrator --timeout=5m

# Step 4: Instance
oc apply -k automation-orchestrator/instance/overlays/default
```

## Post-Deployment Verification

After deployment completes:

```bash
# 1. Check all pods are running
oc get pods -n automation-orchestrator
# Expected: All pods in Running state (1/1 or 2/2)

# 2. Get AutomationOrchestrator status
oc get automationorchestrator -n automation-orchestrator
# Expected: STATUS column shows "Running" or "Ready"

# 3. Check route
oc get route automation-orchestrator -n automation-orchestrator
# Should show a route URL

# 4. Get admin password
oc get secret automation-orchestrator-admin-password \
  -n automation-orchestrator \
  -o jsonpath='{.data.password}' | base64 -d
echo

# 5. Access UI
URL=$(oc get route automation-orchestrator -n automation-orchestrator -o jsonpath='{.spec.host}')
echo "Access UI at: https://$URL"
echo "Username: admin"
echo "Password: (from step 4)"
```

## Troubleshooting Commands

If deployment issues occur:

```bash
# Check operator logs
oc logs -l control-plane=controller-manager -n automation-orchestrator

# Check AutomationOrchestrator events
oc describe automationorchestrator automation-orchestrator -n automation-orchestrator

# Check pod events
oc get events -n automation-orchestrator --sort-by='.lastTimestamp'

# Check database connectivity
oc exec postgresql-0 -n automation-orchestrator -- pg_isready -U postgres

# View database init job logs
oc logs job/postgresql-init-databases -n automation-orchestrator

# Check all resources
oc get all -n automation-orchestrator
```

## Success Criteria

Deployment is successful when:

- [ ] All pods show "Running" status (1/1 or 2/2)
- [ ] AutomationOrchestrator CR shows "Ready" or "Running" status
- [ ] Route is accessible (curl returns HTTP 200 or redirect)
- [ ] UI loads in browser
- [ ] Can login with admin credentials
- [ ] Dashboard displays without errors

## Rollback Plan

If deployment fails:

```bash
# Remove instance
oc delete automationorchestrator automation-orchestrator -n automation-orchestrator

# Wait for cleanup
oc wait --for=delete pod -l app.kubernetes.io/name=automation-orchestrator \
  -n automation-orchestrator --timeout=5m

# Optionally remove PostgreSQL (WARNING: deletes all data)
oc delete statefulset postgresql -n automation-orchestrator
oc delete pvc postgresql-data-postgresql-0 -n automation-orchestrator

# Fix issues, then redeploy
```

## Next Steps After Successful Deployment

1. Access the UI and complete initial setup
2. Create your first EDA project
3. Configure decision environments
4. Set up event sources (webhooks, Kafka, etc.)
5. Review security settings
6. Plan transition to production (if POC)

## Production Readiness

Before moving to production:

- [ ] Replace placeholder secrets with secure passwords
- [ ] Use external managed PostgreSQL
- [ ] Enable SSL/TLS for database connections
- [ ] Configure backup strategy
- [ ] Set up monitoring and alerting
- [ ] Review and apply resource limits
- [ ] Configure LDAP/SAML authentication
- [ ] Set up custom TLS certificates
- [ ] Configure S3 storage for file uploads
- [ ] Test disaster recovery procedures

See [docs/complete-installation.md](docs/complete-installation.md) for production deployment guide.

---

**Ready to deploy?** All validations passed - you're good to go!
