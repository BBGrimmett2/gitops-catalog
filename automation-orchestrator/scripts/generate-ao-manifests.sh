#!/bin/bash
# Generate Automation Orchestrator manifest using aapctl
# Usage: ./generate-ao-manifests.sh [additional aapctl args]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
OUTPUT_FILE="$PROJECT_ROOT/instance/base/automationorchestrator.yaml"
KUSTOMIZATION_FILE="$PROJECT_ROOT/instance/base/kustomization.yaml"

# Check if aapctl is installed
if ! command -v aapctl &> /dev/null; then
    echo "Error: aapctl is not installed or not in PATH"
    echo "Please install aapctl before running this script"
    exit 1
fi

echo "Generating Automation Orchestrator manifests using aapctl..."

# Default configuration for PostgreSQL if not provided
DEFAULT_ARGS=(
    "--set" "automation-orchestrator-cr.postgres.host=postgresql.automation-orchestrator.svc.cluster.local"
    "--set" "automation-orchestrator-cr.postgres.sslMode=prefer"
)

# Combine default args with user-provided args
AAPCTL_ARGS=("${DEFAULT_ARGS[@]}" "$@")

# Generate manifests
echo "Running: aapctl install ao --dry-run -o yaml ${AAPCTL_ARGS[*]}"
TEMP_FILE=$(mktemp)

if ! aapctl install ao --dry-run -o yaml "${AAPCTL_ARGS[@]}" > "$TEMP_FILE" 2>&1; then
    echo "Error: aapctl command failed"
    cat "$TEMP_FILE"
    rm "$TEMP_FILE"
    exit 1
fi

# Extract only the AutomationOrchestrator CR and process it
echo "Processing generated manifests..."

# Use yq if available, otherwise use basic grep/sed
if command -v yq &> /dev/null; then
    # Extract AutomationOrchestrator CR, remove namespace, add sync-wave
    yq eval 'select(.kind == "AutomationOrchestrator") | del(.metadata.namespace) | .metadata.annotations."argocd.argoproj.io/sync-wave" = "3"' "$TEMP_FILE" > "$OUTPUT_FILE"
else
    # Fallback to basic text processing
    awk '
        /^---$/ { doc++ }
        doc > 0 && /kind: AutomationOrchestrator/ { ao_doc=doc; print_section=1 }
        print_section && doc == ao_doc {
            if ($0 !~ /  namespace:/) print
        }
        doc != ao_doc && print_section { print_section=0 }
    ' "$TEMP_FILE" | sed '/^---$/d' > "$OUTPUT_FILE"

    # Add sync-wave annotation
    sed -i '' '/^metadata:/a\
  annotations:\
    argocd.argoproj.io/sync-wave: "3"' "$OUTPUT_FILE"
fi

rm "$TEMP_FILE"

if [ ! -s "$OUTPUT_FILE" ]; then
    echo "Error: Failed to extract AutomationOrchestrator CR"
    echo "The generated manifest may be empty or in an unexpected format"
    exit 1
fi

# Update kustomization.yaml to reference the new file
echo "Updating kustomization.yaml..."

# Replace placeholder with actual file
sed -i '' 's/automationorchestrator-placeholder.yaml/automationorchestrator.yaml/' "$KUSTOMIZATION_FILE" || {
    # If the file already references automationorchestrator.yaml, that's fine
    grep -q "automationorchestrator.yaml" "$KUSTOMIZATION_FILE" || {
        echo "Warning: Could not update kustomization.yaml"
        echo "Please manually update $KUSTOMIZATION_FILE to reference automationorchestrator.yaml"
    }
}

echo "Success! AutomationOrchestrator CR generated at: $OUTPUT_FILE"
echo ""
echo "Next steps:"
echo "  1. Review the generated CR: cat $OUTPUT_FILE"
echo "  2. Create secrets: ./scripts/generate-secrets.sh default"
echo "  3. Deploy with kustomize: kustomize build instance/overlays/default"
echo ""
