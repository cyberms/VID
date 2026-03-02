#!/bin/bash
# =============================================================================
# build.sh – Vendor Independence Day (VID)
# Einstiegspunkt für alle Packer-Builds (vom Repository-Root ausführen)
#
# Verwendung:
#   ./build.sh [target]
#
# Targets:
#   w11-base    Windows 11 Basis-Image (Layer 1–3: OS + VMware Tools + Updates)
#   w11-vda     Vollständiges Master-Image (Layer 1–8: inkl. Citrix VDA + MCS-Seal)
#   pipeline    Build + Test-Katalog aktualisieren
#   promote     Letztes Image in Prod-Katalog promoten
#   server2022  Windows Server 2022 Image
#
# Kein Target → w11-vda (vollständiger Build)
# =============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKER_DIR="$REPO_ROOT/packer"
CONFIG_DIR="$PACKER_DIR/config"

# ── Farben ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok()   { echo -e "${GREEN}  ✓${NC} $1"; }
warn() { echo -e "${YELLOW}  !${NC} $1"; }
err()  { echo -e "${RED}  ✗${NC} $1"; }

# ── Voraussetzungen prüfen ────────────────────────────────────────────────────
check_prerequisites() {
  echo ""
  echo "Prüfe Voraussetzungen..."

  local failed=0

  # Packer
  if command -v packer &>/dev/null; then
    ok "packer $(packer version | head -1)"
  else
    err "packer nicht gefunden. Installation: https://developer.hashicorp.com/packer/tutorials/docker-get-started/get-started-install-cli"
    failed=1
  fi

  # xorriso (benötigt für cd_files / virtuelle CD-ISO-Erstellung)
  if command -v xorriso &>/dev/null; then
    ok "xorriso $(xorriso --version 2>&1 | head -1)"
  else
    err "xorriso nicht gefunden. Installation: sudo apt install -y xorriso"
    failed=1
  fi

  # Konfigurationsdateien
  for cfg in vsphere.pkrvars.hcl build.pkrvars.hcl sources.pkrvars.hcl; do
    if [ -f "$CONFIG_DIR/$cfg" ]; then
      ok "$cfg"
    else
      err "$cfg fehlt → cp packer/config/${cfg}.example packer/config/${cfg}"
      failed=1
    fi
  done

  if [ $failed -ne 0 ]; then
    echo ""
    err "Voraussetzungen nicht erfüllt. Build abgebrochen."
    echo ""
    exit 1
  fi

  echo ""
}

# ── Main ──────────────────────────────────────────────────────────────────────
echo ""
echo "============================================================"
echo "  Vendor Independence Day – VID Packer Build"
echo "============================================================"

check_prerequisites

cd "$PACKER_DIR"
exec ./create_templates.sh "$@"