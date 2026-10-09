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
oc apply -f https://raw.githubusercontent.com/BBGrimmett2/gitops-catalog/automation-orchestrator/automation-orchestrator/application.yaml
```

ArgoCD will automatically:
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

**WARNING:** These are placeholder credentials for POC/demo only. For production, update secrets before deploying.