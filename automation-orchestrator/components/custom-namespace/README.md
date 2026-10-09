# Custom Namespace Component

This kustomize component allows you to deploy Automation Orchestrator into a namespace with a custom name instead of the default `automation-orchestrator`.

## Usage

Create a new overlay and include this component:

```yaml
# my-overlay/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: my-custom-namespace  # Your custom namespace name

components:
  - ../../components/custom-namespace

resources:
  - ../../operator/base
  - namespace.yaml
```

Create the namespace file with your custom name:

```yaml
# my-overlay/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: my-custom-namespace
  annotations:
    argocd.argoproj.io/sync-wave: "1"
```

## Example: Deploy to `aap-orchestrator` Namespace

```bash
# Create a custom overlay
mkdir -p automation-orchestrator/operator/overlays/aap-orchestrator

# Create kustomization
cat > automation-orchestrator/operator/overlays/aap-orchestrator/kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: aap-orchestrator

components:
  - ../../../components/custom-namespace

resources:
  - ../../base
  - namespace.yaml

patches:
  - target:
      kind: OperatorGroup
      name: automation-orchestrator-operator
    patch: |-
      - op: add
        path: /metadata/annotations
        value:
          argocd.argoproj.io/sync-wave: "2"
      - op: replace
        path: /spec/targetNamespaces
        value:
          - aap-orchestrator
  - target:
      kind: Subscription
      name: automation-orchestrator-operator
    patch: |-
      - op: add
        path: /metadata/annotations
        value:
          argocd.argoproj.io/sync-wave: "2"
EOF

# Create namespace
cat > automation-orchestrator/operator/overlays/aap-orchestrator/namespace.yaml <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: aap-orchestrator
  annotations:
    argocd.argoproj.io/sync-wave: "1"
EOF

# Deploy
oc apply -k automation-orchestrator/operator/overlays/aap-orchestrator
```

## What This Component Does

1. **Namespace Field**: Sets the namespace for all resources
2. **Replacements**: Updates service DNS names in secrets to match the custom namespace
3. **References**: Ensures cross-component references use the correct namespace

## Important Notes

**Database Connection Strings**

If using the bundled PostgreSQL, the component automatically updates the database host in secrets from:
```
postgresql.automation-orchestrator.svc.cluster.local
```
to:
```
postgresql.YOUR-NAMESPACE.svc.cluster.local
```

**Multiple Overlays**

You can create multiple overlays for different namespaces:

```
operator/overlays/
├── default/                      # automation-orchestrator namespace
├── dev/                          # aap-orchestrator-dev namespace
├── staging/                      # aap-orchestrator-staging namespace
└── prod/                         # aap-orchestrator-prod namespace
```

**OperatorGroup**

When deploying to a custom namespace, remember to update the OperatorGroup's `targetNamespaces` to match your custom namespace name (see example above).

## Testing

Verify the custom namespace:

```bash
# Build and check the namespace
kustomize build automation-orchestrator/operator/overlays/YOUR-OVERLAY | grep "namespace:"

# Check database connection strings
kustomize build automation-orchestrator/instance/overlays/YOUR-OVERLAY | grep "host:"
```

## Limitations

- Resource names (like `automation-orchestrator`) remain the same
- You may need to adjust external references (like S3 bucket names, external DNS)
- ArgoCD Application specs need to reference the correct overlay path
