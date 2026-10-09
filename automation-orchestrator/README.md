# Automation Orchestrator for Ansible Automation Platform

This directory provides Kustomize-based manifests for deploying Red Hat Ansible Automation Platform's **Automation Orchestrator** on OpenShift using GitOps principles.

## Overview

Automation Orchestrator enables event-driven automation capabilities within Ansible Automation Platform. This GitOps Catalog entry provides a modular deployment structure that follows Red Hat CoP best practices.

## Directory Structure

```
automation-orchestrator/
├── operator/          Install the Automation Orchestrator operator via OLM
├── postgresql/        Deploy PostgreSQL databases required by Automation Orchestrator
├── instance/          Deploy an Automation Orchestrator instance
├── scripts/           Helper utilities for manifest and secret generation
└── docs/              Additional documentation and examples
```

## POC/Lab Quick Start (2 Commands)

**For POC, Lab, or Demo environments - deploys in under 5 minutes with placeholder passwords:**

```bash
# 1. Install operator
oc apply -k https://github.com/redhat-cop/gitops-catalog/automation-orchestrator/operator/overlays/default?ref=main

# 2. Clone repo and deploy (includes PostgreSQL with placeholder secrets)
git clone https://github.com/redhat-cop/gitops-catalog.git
cd gitops-catalog/automation-orchestrator
./scripts/generate-ao-manifests.sh
oc apply -k instance/overlays/with-postgres
```

**Credentials**: Database password is `RedHat123` - See [docs/QUICKSTART-POC.md](docs/QUICKSTART-POC.md) for details.

**WARNING: This uses placeholder passwords. For production, see the Production Quick Start below.**

---

## Production Quick Start

### 1. Install the Operator

```bash
# Local installation
oc apply -k automation-orchestrator/operator/overlays/default

# Or using remote kustomize reference
oc apply -k github.com/redhat-cop/gitops-catalog/automation-orchestrator/operator/overlays/default?ref=main
```

### 2. Deploy PostgreSQL (Optional)

If you don't have an external PostgreSQL instance:

```bash
oc apply -k automation-orchestrator/postgresql/overlays/default
```

Or with custom storage:

```bash
# Edit postgresql/overlays/custom-storage/pvc-patch.yaml first
oc apply -k automation-orchestrator/postgresql/overlays/custom-storage
```

### 3. Generate Secrets and Deploy Instance

```bash
cd automation-orchestrator

# Generate database credential secrets
./scripts/generate-secrets.sh default

# Generate AutomationOrchestrator custom resource using aapctl
./scripts/generate-ao-manifests.sh

# Deploy the instance
oc apply -k instance/overlays/default
```

Or deploy instance with bundled PostgreSQL:

```bash
./scripts/generate-secrets.sh with-postgres
./scripts/generate-ao-manifests.sh
oc apply -k instance/overlays/with-postgres
```

## Prerequisites

- OpenShift 4.12+ or Kubernetes 1.25+
- ArgoCD (for GitOps deployment)
- `kustomize` CLI tool
- `aapctl` CLI (for generating instance manifests)
- Valid Red Hat subscription with access to Automation Orchestrator operator

## Components

### Operator (`operator/`)
Installs the Automation Orchestrator operator using OpenShift's Operator Lifecycle Manager (OLM).

**Overlays:**
- `default` - Standard operator installation

**Learn more:** [operator/README.md](operator/README.md)

### PostgreSQL (`postgresql/`)
Deploys PostgreSQL with the three databases required by Automation Orchestrator:
- `orchestrator` - Main backend database
- `temporal` - Temporal workflow engine database
- `temporal_visibility` - Temporal visibility store

**Overlays:**
- `default` - Default storage class, 10Gi
- `custom-storage` - Customizable storage class and size

**Learn more:** [postgresql/README.md](postgresql/README.md)

### Instance (`instance/`)
Deploys an Automation Orchestrator instance (custom resource).

**Overlays:**
- `default` - Instance only (requires external PostgreSQL)
- `with-postgres` - Complete stack with bundled PostgreSQL

**Learn more:** [instance/README.md](instance/README.md)

## Helper Scripts

### `scripts/generate-ao-manifests.sh`
Generates the AutomationOrchestrator custom resource using `aapctl`.

```bash
./scripts/generate-ao-manifests.sh [aapctl args]
```

### `scripts/generate-secrets.sh`
Creates database credential secrets from templates with generated passwords.

```bash
./scripts/generate-secrets.sh [overlay-name]
```

### `scripts/validate-manifests.sh`
Validates YAML syntax and kustomize builds.

```bash
./scripts/validate-manifests.sh
```

## ArgoCD Deployment

See [docs/argocd-application-examples.yaml](docs/argocd-application-examples.yaml) for example ArgoCD Application manifests.

## Documentation

- [Complete Installation Guide](docs/complete-installation.md) - End-to-end walkthrough
- [ArgoCD Application Examples](docs/argocd-application-examples.yaml) - Sample ArgoCD apps
- [Operator README](operator/README.md) - Operator installation details
- [PostgreSQL README](postgresql/README.md) - Database deployment guide
- [Instance README](instance/README.md) - Instance configuration and deployment

## Deployment Order (Sync Waves)

When using ArgoCD, resources are deployed in this order:

1. **Wave 1** - Namespace, PostgreSQL StatefulSet/Service, Database Secrets
2. **Wave 2** - PostgreSQL initialization Job, Operator (OperatorGroup/Subscription)
3. **Wave 3** - AutomationOrchestrator custom resource

## Support

For issues related to:
- **Automation Orchestrator product**: Contact Red Hat Support
- **GitOps Catalog**: Open an issue at https://github.com/redhat-cop/gitops-catalog
- **OpenShift**: Refer to Red Hat OpenShift documentation

## License

This GitOps Catalog entry follows the licensing of the Red Hat CoP GitOps Catalog project.

## Contributing

Contributions are welcome! Please follow the Red Hat CoP GitOps Catalog contribution guidelines.
