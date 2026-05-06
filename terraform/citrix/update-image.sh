#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# VID – Phase 1b: Image Update nach Packer-Build
#
# Liest das Packer-Manifest, konstruiert den XDHyp-Pfad des neuen Master
# Images und ruft terraform apply auf.
#
# Verwendung:
#   ./update-image.sh                    # liest Packer-Manifest automatisch
#   ./update-image.sh --catalog VID-W11-Test    # abweichender Katalogname
#   ./update-image.sh --dry-run                 # zeigt Plan ohne Apply
#   ./update-image.sh --image "XDHyp:\..."      # XDHyp-Pfad manuell angeben
#
# Voraussetzungen:
#   - terraform installiert (>= 1.5)
#   - terraform.tfvars mit Credentials und Basis-Konfiguration vorhanden
#   - jq installiert (apt install jq / brew install jq)
#   - Packer-Build abgeschlossen (Manifest unter ../packer/windows/desktop/11/output/)
#
# Image-Update-Workflow:
#   1. Packer baut neues Master Image in vSphere
#   2. Packer schreibt VM-Namen in output/manifest-<target>.json
#   3. Dieses Script liest den VM-Namen, konstruiert den XDHyp-Pfad
#   4. terraform apply aktualisiert den Machine Catalog
#   5. Nicht-persistente VMs erhalten das neue Image beim nächsten Boot
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MANIFEST_PATH="$REPO_ROOT/packer/windows/desktop/11/output/manifest.json"

DRY_RUN=false
MASTER_IMAGE_OVERRIDE=""
CATALOG_NAME_OVERRIDE=""

# ── Argument-Parsing ──────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --image)
      MASTER_IMAGE_OVERRIDE="$2"
      shift 2
      ;;
    --catalog)
      CATALOG_NAME_OVERRIDE="$2"
      shift 2
      ;;
    --manifest)
      MANIFEST_PATH="$2"
      shift 2
      ;;
    -h|--help)
      grep "^#" "$0" | head -30 | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "Unbekannter Parameter: $1"
      exit 1
      ;;
  esac
done

# ── Farben ────────────────────────────────────────────────────────────────────

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

# ── Voraussetzungen prüfen ────────────────────────────────────────────────────

info "=== VID Phase 1b – Citrix DaaS Image Update ==="
info "Arbeitsverzeichnis: $SCRIPT_DIR"

if ! command -v terraform &>/dev/null; then
  error "terraform nicht gefunden. Installieren: https://developer.hashicorp.com/terraform/install"
  exit 1
fi

if ! command -v jq &>/dev/null; then
  error "jq nicht gefunden. Installieren: apt install jq oder brew install jq"
  exit 1
fi

if [[ ! -f "$SCRIPT_DIR/terraform.tfvars" ]]; then
  error "terraform.tfvars nicht gefunden in $SCRIPT_DIR"
  error "Erstelle aus terraform.tfvars.example und trage Werte ein."
  exit 1
fi

# ── Master Image ermitteln ────────────────────────────────────────────────────

if [[ -n "$MASTER_IMAGE_OVERRIDE" ]]; then
  # Manuell angegeben
  MASTER_IMAGE_VM="$MASTER_IMAGE_OVERRIDE"
  info "Master Image (manuell): $MASTER_IMAGE_VM"
else
  # Aus Packer-Manifest lesen
  if [[ ! -f "$MANIFEST_PATH" ]]; then
    error "Packer-Manifest nicht gefunden: $MANIFEST_PATH"
    error "Packer-Build zuerst ausführen: ./build.sh w11-vda"
    exit 1
  fi

  info "Lese Packer-Manifest: $MANIFEST_PATH"

  # VM-Name aus Manifest extrahieren
  # Packer-Manifest format: builds[].artifact_id enthält den VM-Namen
  VM_NAME=$(jq -r '.builds[-1].artifact_id // .builds[0].artifact_id' "$MANIFEST_PATH" 2>/dev/null || true)

  if [[ -z "$VM_NAME" || "$VM_NAME" == "null" ]]; then
    # Fallback: custom_data im Manifest
    VM_NAME=$(jq -r '.builds[-1].custom_data.vm_name // empty' "$MANIFEST_PATH" 2>/dev/null || true)
  fi

  if [[ -z "$VM_NAME" || "$VM_NAME" == "null" ]]; then
    error "VM-Name konnte nicht aus Manifest gelesen werden."
    error "Manifest-Inhalt:"
    jq '.' "$MANIFEST_PATH" || cat "$MANIFEST_PATH"
    error ""
    error "Alternativ: --image 'XDHyp:\\Connections\\...' angeben."
    exit 1
  fi

  ok "VM-Name aus Manifest: $VM_NAME"

  # XDHyp-Pfad aus terraform.tfvars lesen (Verbindung + Datacenter + Cluster extrahieren)
  # Wir lesen die bestehende master_image_vm-Variable und ersetzen nur den VM-Namen
  CURRENT_IMAGE=$(grep 'master_image_vm' "$SCRIPT_DIR/terraform.tfvars" | \
    sed 's/.*=\s*"\(.*\)"/\1/' | sed "s/\\\\\\\\/'\\\\'/g" | head -1)

  if [[ -z "$CURRENT_IMAGE" ]]; then
    error "master_image_vm nicht in terraform.tfvars gefunden."
    error "Beim ersten Run: --image 'XDHyp:\\...' manuell angeben."
    exit 1
  fi

  # VM-Namen im Pfad ersetzen: alles bis zur letzten \.vm\... ersetzen
  BASE_PATH=$(echo "$CURRENT_IMAGE" | sed 's|\\[^\\]*\.vm\\.*||')
  MASTER_IMAGE_VM="${BASE_PATH}\\${VM_NAME}.vm\\packer-snapshot.snapshot"
  info "Konstruierter XDHyp-Pfad: $MASTER_IMAGE_VM"
fi

# ── Katalogname (optional override) ──────────────────────────────────────────

TF_VARS="-var=\"master_image_vm=${MASTER_IMAGE_VM}\""
if [[ -n "$CATALOG_NAME_OVERRIDE" ]]; then
  TF_VARS="$TF_VARS -var=\"catalog_name=${CATALOG_NAME_OVERRIDE}\""
  info "Katalog (Override): $CATALOG_NAME_OVERRIDE"
fi

# ── Terraform Init (falls noch nicht initialisiert) ───────────────────────────

cd "$SCRIPT_DIR"

if [[ ! -d ".terraform" ]]; then
  info "Terraform initialisieren..."
  terraform init
fi

# ── Terraform Plan ────────────────────────────────────────────────────────────

info "=== terraform plan ==="
eval "terraform plan $TF_VARS"

if [[ "$DRY_RUN" == "true" ]]; then
  warn "Dry-Run: terraform apply wird nicht ausgeführt."
  exit 0
fi

# ── Bestätigung ───────────────────────────────────────────────────────────────

echo ""
echo -e "${YELLOW}Neues Master Image:${NC}"
echo "  $MASTER_IMAGE_VM"
echo ""
read -rp "terraform apply ausführen? [y/N] " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
  warn "Abgebrochen."
  exit 0
fi

# ── Terraform Apply ───────────────────────────────────────────────────────────

info "=== terraform apply ==="
eval "terraform apply -auto-approve $TF_VARS"

ok "=== Image Update abgeschlossen ==="
echo ""
info "Nicht-persistente VMs erhalten das neue Image beim nächsten Neustart."
info "Monitoring: Citrix DaaS Console → Machine Catalogs → $(grep 'catalog_name' terraform.tfvars | awk -F'"' '{print $2}' || echo 'VID-W11-MCS')"
