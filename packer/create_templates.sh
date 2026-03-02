#!/bin/bash

##########################################################################
# create_templates.sh
# Vendor Independence Day (VID) – Packer Build Script
#
# Baut Windows 11 + Citrix VDA Master Images für zwei Hypervisor-Plattformen:
#   - VMware vSphere  (Layer 6: VMware Tools, Builder: vsphere-iso)
#   - XenServer       (Layer 6: Citrix VM Tools, Builder: xenserver-iso)
#
# VID Layer-Zuordnung:
#   Layer 5 – W11 OS   : identisch für beide Hypervisoren
#   Layer 6 – Drivers  : hypervisor-spezifisch (VMware Tools / XenServer Tools)
#   Layer 7 – VDA+Prof : identisch für beide Hypervisoren (Citrix VDA + Optimize + MCS-Prep)
#
# ── HYPERVISOR-AUSWAHL ─────────────────────────────────────────────────────
# Aktiver Hypervisor: VMware vSphere
# Zum Wechseln: Die gewünschte Zeile auskommentieren, die andere einkommentieren.
#
#   HYPERVISOR="vmware"       # → vsphere-iso Builder, VMware Tools
#   HYPERVISOR="xenserver"    # → xenserver-iso Builder, Citrix VM Tools
# ─────────────────────────────────────────────────────────────────────────────

HYPERVISOR="vmware"         # ← AKTIV: VMware vSphere
# HYPERVISOR="xenserver"    # ← INAKTIV: XenServer / Citrix Hypervisor

# ── CITRIX DAAS KONFIGURATION (für pipeline + promote Targets) ───────────────
# Wird nur benötigt wenn ./create_templates.sh pipeline oder promote aufgerufen wird.
# update-image.ps1 muss auf einem Windows-Host mit Citrix DaaS SDK ausgeführt werden.

CITRIX_CLIENT_ID=""         # Citrix Cloud Secure Client ID
CITRIX_CLIENT_SECRET=""     # Citrix Cloud Secure Client Secret
CITRIX_CUSTOMER_ID=""       # Citrix Cloud Customer ID

TEST_CATALOG="W11-Test"     # Name des Test-Maschinenkatalogs
PROD_CATALOG="W11-Prod"     # Name des Prod-Maschinenkatalogs

# vSphere-Verbindungsname in Citrix DaaS (unter "Hosting Connections")
VSPHERE_CONNECTION="vSphere-euc-demo"
VSPHERE_DATACENTER="Datacenter"
VSPHERE_CLUSTER="cluster01"

# ─────────────────────────────────────────────────────────────────────────────

BUILD_TARGET="${1:-all}"

# ── Windows 11 + Citrix VDA auf VMware vSphere ───────────────────────────────
build_w11_vda_vmware() {
  echo ""
  echo "=========================================================="
  echo "  [VID] Building Windows 11 + Citrix VDA Master Image"
  echo "  Hypervisor : VMware vSphere  [Layer 6: VMware Tools]"
  echo "  Broker     : Citrix DaaS MCS [Layer 7: VDA + Optimize]"
  echo "=========================================================="

  echo "[1/3] Initializing Packer plugins..."
  packer init ./windows/desktop/11/

  echo "[2/3] Starting Packer build (vsphere-iso)..."
  packer build -force \
    --only vsphere-iso.windows-desktop \
    -var-file=./config/vsphere.pkrvars.hcl \
    -var-file=./config/build.pkrvars.hcl \
    -var-file=./config/common.pkrvars.hcl \
    -var-file=./config/sources.pkrvars.hcl \
    ./windows/desktop/11/windows.pkr.hcl

  BUILD_EXIT=$?
  if [ $BUILD_EXIT -eq 0 ]; then
    echo "[3/3] W11 + Citrix VDA (VMware) build SUCCESS."
    echo "      Next step: Run citrix-mcs/deploy-citrix-mcs.ps1 to provision VMs."
  else
    echo "[3/3] W11 + Citrix VDA (VMware) build FAILED (exit code: $BUILD_EXIT)."
    echo "      Check Packer output and logs in packer/manifests/"
    exit $BUILD_EXIT
  fi
}

# ── Windows 11 + Citrix VDA auf XenServer ────────────────────────────────────
build_w11_vda_xenserver() {
  echo ""
  echo "=========================================================="
  echo "  [VID] Building Windows 11 + Citrix VDA Master Image"
  echo "  Hypervisor : XenServer / Citrix Hypervisor  [Layer 6: Citrix VM Tools]"
  echo "  Broker     : Citrix DaaS MCS                [Layer 7: VDA + Optimize]"
  echo "=========================================================="

  echo "[1/3] Initializing Packer plugins..."
  packer init ./windows/desktop/11-xenserver/

  echo "[2/3] Starting Packer build (xenserver-iso)..."
  packer build -force \
    -var-file=./config/xenserver.pkrvars.hcl \
    -var-file=./config/build.pkrvars.hcl \
    -var-file=./config/common.pkrvars.hcl \
    -var-file=./config/sources.pkrvars.hcl \
    ./windows/desktop/11-xenserver/windows.pkr.hcl

  BUILD_EXIT=$?
  if [ $BUILD_EXIT -eq 0 ]; then
    echo "[3/3] W11 + Citrix VDA (XenServer) build SUCCESS."
    echo "      Output: artifacts/xenserver/ (XVA format)"
    echo "      Next step: Import XVA in XenCenter, then run MCS deployment."
  else
    echo "[3/3] W11 + Citrix VDA (XenServer) build FAILED (exit code: $BUILD_EXIT)."
    echo "      Check Packer output and logs in packer/manifests/"
    exit $BUILD_EXIT
  fi
}

# ── Windows 11 Base Image – nur Layer 5 (kein VDA) ───────────────────────────
build_w11_base() {
  echo ""
  echo "=========================================================="
  echo "  [VID] Building Windows 11 Base Image (Layer 5 only)"
  echo "  Hypervisor : $HYPERVISOR  [Layer 6: Drivers]"
  echo "  Broker     : KEINER – reines OS-Image zum Testen"
  echo "=========================================================="

  local packer_dir
  if [ "$HYPERVISOR" = "xenserver" ]; then
    packer_dir="./windows/desktop/11-xenserver/"
  else
    packer_dir="./windows/desktop/11/"
  fi

  echo "[1/3] Initializing Packer plugins..."
  packer init "$packer_dir"

  echo "[2/3] Starting Packer build (Layer 5 only, build_layer5_only=true)..."
  packer build -force \
    --only vsphere-iso.windows-desktop \
    -var "build_layer5_only=true" \
    -var-file=./config/vsphere.pkrvars.hcl \
    -var-file=./config/build.pkrvars.hcl \
    -var-file=./config/common.pkrvars.hcl \
    -var-file=./config/sources.pkrvars.hcl \
    "$packer_dir"

  BUILD_EXIT=$?
  if [ $BUILD_EXIT -eq 0 ]; then
    echo "[3/3] W11 Base Image (Layer 5) build SUCCESS."
    echo "      Nächster Schritt: ./create_templates.sh w11-vda für vollständigen Build mit VDA."
  else
    echo "[3/3] W11 Base Image (Layer 5) build FAILED (exit code: $BUILD_EXIT)."
    exit $BUILD_EXIT
  fi
}

# ── Windows 11 + Citrix VDA (Hypervisor via HYPERVISOR-Variable) ─────────────
build_w11_vda() {
  case "$HYPERVISOR" in
    "vmware")
      build_w11_vda_vmware
      ;;
    "xenserver")
      build_w11_vda_xenserver
      ;;
    *)
      echo "ERROR: Unbekannter Hypervisor '$HYPERVISOR'."
      echo "       Gültige Werte: vmware | xenserver"
      exit 1
      ;;
  esac
}

# ── Windows Server 2022 ───────────────────────────────────────────────────────
build_server2022() {
  echo ""
  echo "=========================================================="
  echo "  Building Windows Server 2022 Templates"
  echo "  Hypervisor: $HYPERVISOR"
  echo "=========================================================="

  echo "[1/3] Initializing Packer plugins..."
  packer init ./windows/server/2022/

  echo "[2/3] Starting Packer build..."
  packer build -force \
    --only vsphere-iso.windows-server-standard-dexp,vsphere-iso.windows-server-standard-core \
    -var-file=./config/vsphere.pkrvars.hcl \
    -var-file=./config/build.pkrvars.hcl \
    -var-file=./config/common.pkrvars.hcl \
    -var-file=./config/sources.pkrvars.hcl \
    ./windows/server/2022/windows-server.pkr.hcl

  BUILD_EXIT=$?
  if [ $BUILD_EXIT -eq 0 ]; then
    echo "[3/3] Windows Server 2022 build SUCCESS."
  else
    echo "[3/3] Windows Server 2022 build FAILED (exit code: $BUILD_EXIT)."
    exit $BUILD_EXIT
  fi
}

# ── Hilfsfunktion: letzten Packer-Build aus Manifest lesen ───────────────────
get_last_image_name() {
  local manifest_dir="./manifests"
  local latest_manifest
  latest_manifest=$(ls -t "${manifest_dir}"/*.json 2>/dev/null | head -1)

  if [ -z "$latest_manifest" ]; then
    echo ""
    return 1
  fi

  # Lese den VM-Namen aus dem Packer Manifest (JSON)
  local vm_name
  vm_name=$(python3 -c "
import json, sys
with open('${latest_manifest}') as f:
    m = json.load(f)
builds = m.get('builds', [])
if builds:
    print(builds[-1].get('artifact_id', '').split('::')[-1])
" 2>/dev/null)

  echo "$vm_name"
}

# ── Pipeline: Build + Test-Katalog aktualisieren ─────────────────────────────
run_pipeline() {
  echo ""
  echo "=========================================================="
  echo "  [VID] Pipeline: Packer Build → Test-Katalog"
  echo "  Schritt 1: Image bauen"
  echo "  Schritt 2: Test-Katalog '$TEST_CATALOG' aktualisieren"
  echo "=========================================================="

  # Schritt 1: Image bauen
  build_w11_vda
  local build_exit=$?
  if [ $build_exit -ne 0 ]; then
    echo "[PIPELINE] Build fehlgeschlagen – Pipeline abgebrochen."
    exit $build_exit
  fi

  # Schritt 2: Image-Namen aus Manifest lesen
  local vm_name
  vm_name=$(get_last_image_name)
  if [ -z "$vm_name" ]; then
    echo "[PIPELINE] WARNUNG: Konnte VM-Namen nicht aus Packer-Manifest lesen."
    echo "           Bitte MasterImageVM manuell angeben und update-image.ps1 direkt aufrufen."
    exit 1
  fi

  local master_image="XDHyp:\\Connections\\${VSPHERE_CONNECTION}\\${VSPHERE_DATACENTER}.datacenter\\${VSPHERE_CLUSTER}.cluster\\${vm_name}.vm\\packer-snapshot.snapshot"

  echo ""
  echo "[PIPELINE] Neues Image: $vm_name"
  echo "[PIPELINE] Aktualisiere Test-Katalog: $TEST_CATALOG"
  echo ""
  echo "  Hinweis: update-image.ps1 muss auf einem Windows-Host mit"
  echo "  installiertem Citrix DaaS Remote PowerShell SDK ausgeführt werden."
  echo ""
  echo "  Befehl für Windows-Host:"
  echo "  .\update-image.ps1 \\"
  echo "    -CitrixClientId     '$CITRIX_CLIENT_ID' \\"
  echo "    -CitrixClientSecret '$CITRIX_CLIENT_SECRET' \\"
  echo "    -CustomerId         '$CITRIX_CUSTOMER_ID' \\"
  echo "    -CatalogName        '$TEST_CATALOG' \\"
  echo "    -MasterImageVM      '$master_image'"
  echo ""
  echo "  Nach erfolgreichem Test:"
  echo "  ./create_templates.sh promote $vm_name"
}

# ── Promote: Test-Image in Prod-Katalog übernehmen ───────────────────────────
run_promote() {
  local vm_name="${2}"

  # Wenn kein VM-Name übergeben wurde, aus Manifest lesen
  if [ -z "$vm_name" ]; then
    vm_name=$(get_last_image_name)
    if [ -z "$vm_name" ]; then
      echo "[PROMOTE] FEHLER: Kein VM-Name angegeben und kein Packer-Manifest gefunden."
      echo "          Verwendung: ./create_templates.sh promote <vm-name>"
      exit 1
    fi
  fi

  local master_image="XDHyp:\\Connections\\${VSPHERE_CONNECTION}\\${VSPHERE_DATACENTER}.datacenter\\${VSPHERE_CLUSTER}.cluster\\${vm_name}.vm\\packer-snapshot.snapshot"

  echo ""
  echo "=========================================================="
  echo "  [VID] Promote: Test → Produktion"
  echo "  Image:         $vm_name"
  echo "  Prod-Katalog:  $PROD_CATALOG"
  echo "=========================================================="
  echo ""
  echo "  Befehl für Windows-Host:"
  echo "  .\update-image.ps1 \\"
  echo "    -CitrixClientId     '$CITRIX_CLIENT_ID' \\"
  echo "    -CitrixClientSecret '$CITRIX_CLIENT_SECRET' \\"
  echo "    -CustomerId         '$CITRIX_CUSTOMER_ID' \\"
  echo "    -CatalogName        '$PROD_CATALOG' \\"
  echo "    -MasterImageVM      '$master_image'"
  echo ""
}

# ── Dispatch ──────────────────────────────────────────────────────────────────
echo ""
echo "Vendor Independence Day – Packer Build"
echo "Aktiver Hypervisor: $HYPERVISOR"
echo ""

case "$BUILD_TARGET" in
  "w11-base")
    # Nur Layer 5: W11 OS + Updates, kein VDA – für Testläufe
    build_w11_base
    ;;
  "w11-vda")
    # Vollständiger Build: Layer 5 + 6 + 7 (OS + Drivers + VDA)
    build_w11_vda
    ;;
  "server2022")
    build_server2022
    ;;
  "pipeline")
    # Packer Build + Test-Katalog aktualisieren
    run_pipeline
    ;;
  "promote")
    # Letztes Build-Image in Prod-Katalog promoten
    # Optional: ./create_templates.sh promote <vm-name>
    run_promote "$@"
    ;;
  "all"|*)
    build_w11_vda
    build_server2022
    ;;
esac

echo ""
echo "Alle angeforderten Builds abgeschlossen."


