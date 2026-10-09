# Automation Orchestrator - Quick Reference

## POC/Lab Deployment (Under 5 Minutes)

```bash
# 1. Install operator
oc apply -k https://github.com/redhat-cop/gitops-catalog/automation-orchestrator/operator/overlays/default?ref=main

# 2. Wait for operator (2-3 minutes)
oc wait --for=condition=ready pod -l control-plane=controller-manager -n automation-orchestrator --timeout=10m

# 3. Deploy complete stack
oc apply -k https://github.com/redhat-cop/gitops-catalog/automation-orchestrator/instance/overlays/with-postgres?ref=main

# 4. Get UI URL and admin password
echo "https://$(oc get route automation-orchestrator -n automation-orchestrator -o jsonpath='{.spec.host}')"
oc get secret automation-orchestrator-admin-password -n automation-orchestrator -o jsonpath='{.data.password}' | base64 -d
```

**Default Credentials**: Database password is `RedHat123`

**WARNING**: This is for POC/Lab only. See Production Deployment for secure installation.

---

## Production Deployment

```bash
# 1. Install operator
oc apply -k automation-orchestrator/operator/overlays/default

# 2. Generate secure secrets
cd automation-orchestrator
./scripts/generate-secrets.sh default

# 3. Deploy instance
oc apply -k instance/overlays/default
```

---

## Deployment Options

| Option | Use Case | Command |
|--------|----------|---------|
| Complete Stack (bundled PostgreSQL) | POC/Lab | `oc apply -k instance/overlays/with-postgres` |
| Instance Only (external DB) | Production | `oc apply -k instance/overlays/default` |
| Custom Storage | Production SSD | `oc apply -k postgresql/overlays/custom-storage` |

---

## Placeholder Credentials (POC/Lab Only)

| Component | Username | Password |
|-----------|----------|----------|
| Orchestrator DB | orchestrator | RedHat123 |
| Temporal DB | temporal | RedHat123 |
| PostgreSQL Admin | postgres | changeme |

---

## Helper Scripts

```bash
# Generate database secrets with secure passwords
./scripts/generate-secrets.sh [overlay-name]

# Validate all manifests and kustomize builds
./scripts/validate-manifests.sh
```

---

## Common Operations

### Get Status
```bash
oc get automationorchestrator -n automation-orchestrator
oc get pods -n automation-orchestrator
```

### View Logs
```bash
# All Automation Orchestrator pods
oc logs -l app.kubernetes.io/name=automation-orchestrator -n automation-orchestrator

# PostgreSQL
oc logs postgresql-0 -n automation-orchestrator
```

### Access Database
```bash
# Connect to PostgreSQL
oc exec -it postgresql-0 -n automation-orchestrator -- psql -U postgres
```

---

## Documentation

- [README.md](README.md) - Overview and quick start
- [PRE-DEPLOYMENT-CHECKLIST.md](PRE-DEPLOYMENT-CHECKLIST.md) - Validation steps
- [docs/QUICKSTART-POC.md](docs/QUICKSTART-POC.md) - POC deployment guide
- [docs/complete-installation.md](docs/complete-installation.md) - Production guide
- [docs/argocd-application-examples.yaml](docs/argocd-application-examples.yaml) - ArgoCD examples
