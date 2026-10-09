#!/bin/bash
# Validate Automation Orchestrator manifests
# Usage: ./validate-manifests.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

ERRORS=0
WARNINGS=0

echo "==================================="
echo "Automation Orchestrator Manifest Validator"
echo "==================================="
echo ""

# Check if required tools are installed
if ! command -v kustomize &> /dev/null; then
    echo "Error: kustomize is not installed"
    echo "Install from: https://kubectl.docs.kubernetes.io/installation/kustomize/"
    exit 1
fi

# Function to check YAML syntax
check_yaml_syntax() {
    local file="$1"
    if command -v yamllint &> /dev/null; then
        if ! yamllint -d relaxed "$file" 2>/dev/null; then
            echo "  ✗ YAML syntax error in $file"
            ((ERRORS++))
            return 1
        fi
    else
        # Basic syntax check with Python
        if command -v python3 &> /dev/null; then
            if ! python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>/dev/null; then
                echo "  ✗ YAML syntax error in $file"
                ((ERRORS++))
                return 1
            fi
        fi
    fi
    return 0
}

# Check for namespaces in base files
echo "Checking for namespaces in base files..."
if grep -r "^  namespace:" "$PROJECT_ROOT"/*/base/*.yaml 2>/dev/null; then
    echo "  ✗ Found namespace in base files (should be in overlays only)"
    ((ERRORS++))
else
    echo "  ✓ No namespaces in base files"
fi
echo ""

# Validate kustomize builds
echo "Validating kustomize builds..."
echo ""

# Operator
echo "1. Operator (overlays/default):"
if kustomize build "$PROJECT_ROOT/operator/overlays/default" > /dev/null 2>&1; then
    echo "  ✓ Build successful"
else
    echo "  ✗ Build failed"
    ((ERRORS++))
fi
echo ""

# PostgreSQL
echo "2. PostgreSQL (overlays/default):"
if kustomize build "$PROJECT_ROOT/postgresql/overlays/default" > /dev/null 2>&1; then
    echo "  ✓ Build successful"
else
    echo "  ✗ Build failed"
    ((ERRORS++))
fi
echo ""

echo "3. PostgreSQL (overlays/custom-storage):"
if kustomize build "$PROJECT_ROOT/postgresql/overlays/custom-storage" > /dev/null 2>&1; then
    echo "  ✓ Build successful"
else
    echo "  ✗ Build failed"
    ((ERRORS++))
fi
echo ""

# Instance
echo "4. Instance (overlays/default):"
if kustomize build "$PROJECT_ROOT/instance/overlays/default" > /dev/null 2>&1; then
    echo "  ✓ Build successful"
    # Check if secrets are included
    if ! kustomize build "$PROJECT_ROOT/instance/overlays/default" 2>/dev/null | grep -q "orchestrator-pg-credentials"; then
        echo "  ⚠ Warning: No database secrets found (expected - create from templates)"
        ((WARNINGS++))
    fi
else
    echo "  ✗ Build failed"
    ((ERRORS++))
fi
echo ""

echo "5. Instance (overlays/with-postgres):"
if kustomize build "$PROJECT_ROOT/instance/overlays/with-postgres" > /dev/null 2>&1; then
    echo "  ✓ Build successful"
    # Verify PostgreSQL is included
    if kustomize build "$PROJECT_ROOT/instance/overlays/with-postgres" 2>/dev/null | grep -q "kind: StatefulSet"; then
        echo "  ✓ PostgreSQL StatefulSet included"
    else
        echo "  ✗ PostgreSQL StatefulSet not found"
        ((ERRORS++))
    fi
else
    echo "  ✗ Build failed"
    ((ERRORS++))
fi
echo ""

# Check sync-wave annotations
echo "Checking ArgoCD sync-wave annotations..."
TEMP_OPERATOR=$(mktemp)
TEMP_POSTGRES=$(mktemp)
TEMP_INSTANCE=$(mktemp)

kustomize build "$PROJECT_ROOT/operator/overlays/default" > "$TEMP_OPERATOR" 2>/dev/null || true
kustomize build "$PROJECT_ROOT/postgresql/overlays/default" > "$TEMP_POSTGRES" 2>/dev/null || true
kustomize build "$PROJECT_ROOT/instance/overlays/default" > "$TEMP_INSTANCE" 2>/dev/null || true

if grep -q 'argocd.argoproj.io/sync-wave: "1"' "$TEMP_OPERATOR"; then
    echo "  ✓ Operator has wave 1 (Namespace)"
else
    echo "  ✗ Missing sync-wave 1 in operator"
    ((ERRORS++))
fi

if grep -q 'argocd.argoproj.io/sync-wave: "2"' "$TEMP_OPERATOR"; then
    echo "  ✓ Operator has wave 2 (OperatorGroup/Subscription)"
else
    echo "  ✗ Missing sync-wave 2 in operator"
    ((ERRORS++))
fi

if grep -q 'argocd.argoproj.io/sync-wave: "3"' "$TEMP_INSTANCE"; then
    echo "  ✓ Instance has wave 3 (AutomationOrchestrator CR)"
else
    echo "  ⚠ Warning: Missing sync-wave 3 in instance (expected if using placeholder)"
    ((WARNINGS++))
fi

rm "$TEMP_OPERATOR" "$TEMP_POSTGRES" "$TEMP_INSTANCE"
echo ""

# Summary
echo "==================================="
echo "Validation Summary"
echo "==================================="
echo "Errors:   $ERRORS"
echo "Warnings: $WARNINGS"
echo ""

if [ $ERRORS -eq 0 ]; then
    echo "✓ All validations passed!"
    exit 0
else
    echo "✗ Validation failed with $ERRORS error(s)"
    exit 1
fi
