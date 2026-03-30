#!/bin/bash
# VID Packer – Lokales Validierungs-Script
# Ersetzt pre-commit wenn keine Python-Umgebung verfügbar ist.
#
# Verwendung:
#   ./packer/validate.sh                          # alle Templates prüfen
#   ./packer/validate.sh --fmt-only               # nur formatieren
#   ./packer/validate.sh windows/desktop/11       # einzelnes Template
#
# Voraussetzungen:
#   packer init wird automatisch pro Template ausgeführt (lädt Plugins herunter)
#   export PKR_VAR_vsphere_password="..."         # Secrets via Env (optional, Dummy wird gesetzt)
#   export PKR_VAR_build_password="..."
#   export PKR_VAR_vid_smb_password="..."
#
# Hypervisor-Trennung:
#   Templates mit "xenserver" im Pfad → eigene Dummy-Vars, keine vSphere-var-files
#   Alle anderen Templates            → vSphere/common/sources/build var-files

set -euo pipefail

PACKER="${PACKER_CMD:-packer}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGETS=(
    "windows/desktop/11"
    # "windows/desktop/11-xenserver"  # WIP – XenServer plugin setup ausstehend
    "windows/desktop/10"
    "windows/server/2022"
    "windows/server/2019"
)

# Einzelnes Target wenn als Argument übergeben
if [[ $# -ge 1 && "$1" != "--fmt-only" ]]; then
    TARGETS=("$1")
fi

FMT_ONLY=false
[[ "${1:-}" == "--fmt-only" ]] && FMT_ONLY=true

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  VID Packer – fmt + validate                             ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

ERRORS=0

for target in "${TARGETS[@]}"; do
    DIR="${SCRIPT_DIR}/${target}"
    [[ -d "$DIR" ]] || { echo "⚠  Übersprungen (nicht gefunden): $target"; continue; }

    echo "── $target"

    # packer fmt (formatiert + zeigt Diff)
    echo -n "   fmt       ... "
    if "$PACKER" fmt -check "$DIR" &>/dev/null; then
        echo "✓"
    else
        "$PACKER" fmt "$DIR"
        echo "✓ (Formatierung korrigiert)"
    fi

    $FMT_ONLY && continue

    # packer init (idempotent – installiert Plugins falls noch nicht vorhanden)
    echo -n "   init      ... "
    if "$PACKER" init "$DIR" &>/dev/null; then
        echo "✓"
    else
        echo "✗ FEHLER (packer init fehlgeschlagen)"
        ERRORS=$((ERRORS + 1))
        echo ""
        continue
    fi

    # packer validate – var-files je nach Hypervisor-Typ trennen
    echo -n "   validate  ... "
    if [[ "$target" == *"xenserver"* ]]; then
        # XenServer-Template: keine vSphere/common-var-files, eigene Dummy-Werte
        PKR_VAR_build_password="${PKR_VAR_build_password:-VALIDATE_DUMMY}" \
        PKR_VAR_build_username="${PKR_VAR_build_username:-administrator}" \
        PKR_VAR_xenserver_host="${PKR_VAR_xenserver_host:-xs-validate.local}" \
        PKR_VAR_xenserver_username="${PKR_VAR_xenserver_username:-root}" \
        PKR_VAR_xenserver_password="${PKR_VAR_xenserver_password:-VALIDATE_DUMMY}" \
        PKR_VAR_xenserver_sr="${PKR_VAR_xenserver_sr:-Local storage}" \
        PKR_VAR_xenserver_sr_iso="${PKR_VAR_xenserver_sr_iso:-XenServer ISOs}" \
        PKR_VAR_xenserver_network="${PKR_VAR_xenserver_network:-VM Network}" \
        PKR_VAR_iso_file="${PKR_VAR_iso_file:-windows11.iso}" \
        "$PACKER" validate "$DIR" \
        && echo "✓" \
        || { echo "✗ FEHLER"; ERRORS=$((ERRORS + 1)); }
    else
        # VMware-Templates: globale var-files + Dummy-Werte für Secrets
        PKR_VAR_vsphere_password="${PKR_VAR_vsphere_password:-VALIDATE_DUMMY}" \
        PKR_VAR_vsphere_username="${PKR_VAR_vsphere_username:-VALIDATE_DUMMY}" \
        PKR_VAR_build_password="${PKR_VAR_build_password:-VALIDATE_DUMMY}" \
        PKR_VAR_build_username="${PKR_VAR_build_username:-administrator}" \
        PKR_VAR_vid_smb_password="${PKR_VAR_vid_smb_password:-VALIDATE_DUMMY}" \
        PKR_VAR_vid_smb_username="${PKR_VAR_vid_smb_username:-VALIDATE_DUMMY}" \
        PKR_VAR_domain_join_password="${PKR_VAR_domain_join_password:-VALIDATE_DUMMY}" \
        PKR_VAR_domain_join_username="${PKR_VAR_domain_join_username:-VALIDATE_DUMMY}" \
        "$PACKER" validate \
            -var-file="${SCRIPT_DIR}/config/vsphere.pkrvars.hcl" \
            -var-file="${SCRIPT_DIR}/config/common.pkrvars.hcl" \
            -var-file="${SCRIPT_DIR}/config/sources.pkrvars.hcl" \
            -var-file="${SCRIPT_DIR}/config/build.pkrvars.hcl" \
            "$DIR" \
        && echo "✓" \
        || { echo "✗ FEHLER"; ERRORS=$((ERRORS + 1)); }
    fi

    echo ""
done

echo "──────────────────────────────────────────────────────────"
if [[ $ERRORS -eq 0 ]]; then
    echo "✓  Alle Checks bestanden."
else
    echo "✗  $ERRORS Template(s) mit Fehlern."
    exit 1
fi
