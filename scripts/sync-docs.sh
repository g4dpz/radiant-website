#!/bin/bash
# Sync the documents the RADIANT website reads from a cislunar_proposal checkout.
# Usage: scripts/sync-docs.sh [path-to-cislunar_proposal]
#   Source checkout: $1, else $CISLUNAR_PROPOSAL, else ../cislunar_proposal
# The source checkout is only read, never modified.
set -euo pipefail

SRC="${1:-${CISLUNAR_PROPOSAL:-../cislunar_proposal}}"
DEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/docs"

if [ ! -d "$SRC" ]; then
  echo "Error: source checkout not found: $SRC" >&2
  echo "Pass the path as an argument or set CISLUNAR_PROPOSAL." >&2
  exit 1
fi

# Single list of "source (relative to checkout)  ->  destination (relative to docs/)".
# Phase requirements and architecture docs are read by website/routes/docs-*.ts.
# Spec requirements are referenced by specPath in website/content/data.ts.
DOCS=(
  "docs/terrestrial-dtn-phase1/requirements.md|terrestrial-dtn-phase1/requirements.md"
  "docs/qo-100-geo-satellite-dtn/requirements.md|qo-100-geo-satellite-dtn/requirements.md"
  "docs/cubesat-em-phase2/requirements.md|cubesat-em-phase2/requirements.md"
  "docs/leo-cubesat-phase3/requirements.md|leo-cubesat-phase3/requirements.md"
  "docs/cislunar-phase4/requirements.md|cislunar-phase4/requirements.md"
  "docs/LTP-KISS-ARCHITECTURE.md|LTP-KISS-ARCHITECTURE.md"
  "docs/DTN-CALLSIGN-EID-CONFIGURATION.md|DTN-CALLSIGN-EID-CONFIGURATION.md"
  ".kiro/specs/contact-log/requirements.md|specs/contact-log/requirements.md"
  ".kiro/specs/station-identification-beacon/requirements.md|specs/station-identification-beacon/requirements.md"
  ".kiro/specs/test-framework-srs-sdd/requirements.md|specs/test-framework-srs-sdd/requirements.md"
  ".kiro/specs/multi-node-contact-graph/requirements.md|specs/multi-node-contact-graph/requirements.md"
  ".kiro/specs/dtn-abstraction-layer/requirements.md|specs/dtn-abstraction-layer/requirements.md"
  ".kiro/specs/contact-plan-as-a-service/requirements.md|specs/contact-plan-as-a-service/requirements.md"
  ".kiro/specs/radiant-network-orchestrator/requirements.md|specs/radiant-network-orchestrator/requirements.md"
)

for entry in "${DOCS[@]}"; do
  from="${entry%%|*}"
  to="${entry##*|}"
  if [ ! -f "$SRC/$from" ]; then
    echo "Error: missing source file: $SRC/$from" >&2
    exit 1
  fi
  mkdir -p "$DEST_ROOT/$(dirname "$to")"
  cp "$SRC/$from" "$DEST_ROOT/$to"
  echo "synced $from -> docs/$to"
done

echo "Done. Review with: git diff --stat docs/"
