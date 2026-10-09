# Automation Orchestrator Operator

Install the Red Hat Automation Orchestrator operator using OpenShift's Operator Lifecycle Manager (OLM).

## What Gets Installed

- **OperatorGroup**: Configures operator to watch the `automation-orchestrator` namespace
- **Subscription**: Subscribes to the `automation-orchestrator-operator` from Red Hat's operator catalog
- **Namespace**: Creates the `automation-orchestrator` namespace

The operator installation registers the `AutomationOrchestrator` custom resource definition (CRD) and starts the operator controller.

## Prerequisites

- OpenShift 4.12+ cluster
- Cluster admin privileges
- Access to Red Hat Operator Catalog (`redhat-operators`)
- Valid Red Hat subscription

## Usage

### Local Installation

Clone this repository and apply the overlay:

```bash
oc apply -k automation-orchestrator/operator/overlays/default
```

### Remote Installation (GitOps)

Apply directly from the GitOps Catalog without cloning:

```bash
oc apply -k github.com/redhat-cop/gitops-catalog/automation-orchestrator/operator/overlays/default?ref=main
```

### ArgoCD Installation

Create an ArgoCD Application:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: automation-orchestrator-operator
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/redhat-cop/gitops-catalog.git
    targetRevision: main
    path: automation-orchestrator/operator/overlays/default
  destination:
    server: https://kubernetes.default.svc
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

## Verify Installation

Check that the operator is running:

```bash
# Wait for the operator pod to be ready
oc get pods -n automation-orchestrator -w

# Verify the CRD is registered
oc get crd automationorchestrators.aap.ansible.com

# Check operator logs
oc logs -n automation-orchestrator -l control-plane=controller-manager -f
```

Expected output:
```
NAME                                                  READY   STATUS    RESTARTS   AGE
automation-orchestrator-operator-controller-manager   2/2     Running   0          2m
```

## Sync Wave

When using ArgoCD, this operator installation uses sync waves:

- **Wave 1**: Namespace creation
- **Wave 2**: OperatorGroup and Subscription

This ensures the namespace exists before the operator resources are created.

## Operator Channel

The operator uses the `stable` channel by default. To use a specific version:

1. Edit `base/subscription.yaml`
2. Change the `channel` field (e.g., `stable-2.x`, `latest`)
3. Commit and sync changes

## Next Steps

After the operator is installed:

1. **Deploy PostgreSQL** (if not using external database):
   ```bash
   oc apply -k ../postgresql/overlays/default
   ```

2. **Create database secrets**:
   ```bash
   cd .. && ./scripts/generate-secrets.sh default
   ```

3. **Generate and deploy instance**:
   ```bash
   ./scripts/generate-ao-manifests.sh
   oc apply -k instance/overlays/default
   ```

## Troubleshooting

### Operator Pod Not Starting

Check the subscription status:
```bash
oc get subscription -n automation-orchestrator
oc describe subscription automation-orchestrator-operator -n automation-orchestrator
```

### CRD Not Registered

Verify the install plan:
```bash
oc get installplan -n automation-orchestrator
oc describe installplan <install-plan-name> -n automation-orchestrator
```

### No Access to Red Hat Operators

Ensure your cluster has:
- Valid Red Hat subscription
- Access to registry.redhat.io
- Proper pull secrets configured

Check operator catalog source:
```bash
oc get catalogsource -n openshift-marketplace
```

## Uninstallation

To remove the operator:

```bash
# Delete the subscription
oc delete subscription automation-orchestrator-operator -n automation-orchestrator

# Delete the operator group
oc delete operatorgroup automation-orchestrator-operator -n automation-orchestrator

# Delete the CSV (ClusterServiceVersion)
oc delete csv -n automation-orchestrator -l operators.coreos.com/automation-orchestrator-operator.automation-orchestrator

# Optionally delete the namespace
oc delete namespace automation-orchestrator
```

**Note**: Deleting the operator does not automatically remove deployed AutomationOrchestrator instances. Delete instances before uninstalling the operator.

## Additional Resources

- [Automation Orchestrator Documentation](https://access.redhat.com/documentation/en-us/red_hat_ansible_automation_platform/)
- [OpenShift Operator Lifecycle Manager](https://docs.openshift.com/container-platform/latest/operators/understanding/olm/olm-understanding-olm.html)
- [GitOps Catalog](https://github.com/redhat-cop/gitops-catalog)
