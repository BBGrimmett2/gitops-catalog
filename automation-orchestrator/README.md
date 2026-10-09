# Automation Orchestrator for Ansible Automation Platform

Two-step deployment of Ansible Automation Platform's Automation Orchestrator using ArgoCD.

## Quick Start

### Step 1: Apply ArgoCD Application

```bash
# Deploy Automation Orchestrator with PostgreSQL
oc apply -f https://raw.githubusercontent.com/BBGrimmett2/gitops-catalog/automation-orchestrator/automation-orchestrator/application.yaml
```

This creates the ArgoCD Application and the target namespace (`ao-demo` by default).

### Step 2: Grant ArgoCD Permissions

After the namespace is created, grant ArgoCD admin permissions:

```bash
# Grant permissions to ArgoCD service account
oc adm policy add-role-to-user admin \
  system:serviceaccount:openshift-gitops:openshift-gitops-argocd-application-controller \
  -n ao-demo
```

**Why is this needed?** ArgoCD needs permissions to create Secrets, Services, StatefulSets, Jobs, and the AutomationOrchestrator custom resource in the namespace.

**Verify permissions (optional):**

```bash
# Should return "yes" after granting
oc auth can-i create secrets \
  --as=system:serviceaccount:openshift-gitops:openshift-gitops-argocd-application-controller \
  -n ao-demo
```

### Step 3: Wait for Automated Deployment

ArgoCD automatically syncs and deploys (retries every ~30 seconds):

1. PostgreSQL 15 with 3 databases
2. Automation Orchestrator operator (via OLM)
3. All Automation Orchestrator components
4. Routes for UI access

**Deployment time:** ~2 minutes from RBAC grant to READY

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

## Default Credentials (POC/Demo)

**PostgreSQL:**
- Password: `RedHat123`

**Admin User:**
- Password: See secret `automation-orchestrator-initial-admin-password`

**WARNING:** These are placeholder credentials for POC/demo only. For production, update secrets before deploying.