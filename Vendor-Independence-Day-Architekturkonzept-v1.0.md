---
title: "Vendor Independence Day – Architekturkonzept"
subtitle: "Phase 1: Schichten 5 (Windows 11), 6 (Treiber), 7 (Applikationen), 8 (DEX/Monitoring)"
version: "1.1"
status: "Entwurf"
date: "März 2026"
audience: "Architekten, Infrastruktur-Engineers, IT-Management"
hypervisors: "VMware vSphere · Citrix Hypervisor (XenServer)"
dex: "ControlUp · uberagent"
---

# Executive Summary

Vendor Independence Day (VID) ist ein Architekturprogramm mit dem Ziel, eine Modern-Workplace-Infrastruktur so zu gestalten, dass jede technologische Schicht unabhängig von den anderen ausgetauscht werden kann -- ohne Betriebsunterbrechung und ohne Neuaufbau der gesamten Umgebung.

Das Schichtenmodell umfasst acht klar definierte Ebenen: von der physischen Hardware über den Hypervisor und dessen Steuerungsschicht, die Verzeichnisdienste, das Gast-Betriebssystem, die Treiberschicht und die Applikationen bis hin zum DEX/Monitoring-Layer. Jede Schicht kann durch eine Alternative ersetzt werden, ohne die darüber- oder darunterliegende Schicht neu konfigurieren zu müssen.

## Phase 1 -- Fokus dieser Dokumentation

Phase 1 betrachtet die Schichten 5, 6 und 7 unter der Annahme, dass ein VMware vSphere-Hypervisor mit vCenter sowie eine Active-Directory-Infrastruktur bereits vorhanden ist. Zusätzlich wird Citrix Hypervisor (XenServer) als zweite Hypervisor-Option eingeführt.

  **Schicht**                      **Technologie Phase 1**                **Austauschbarkeit**
  -------------------------------- -------------------------------------- ------------------------------------------
  **Schicht 5 -- Windows 11 VM**   Packer + vSphere-ISO / XenServer-ISO   Hypervisor-agnostisches Base Image
  **Schicht 6 -- Treiber**         VMware Tools · Citrix VM Tools         Auto-Detection, skriptbasiert
  **Schicht 7 -- Applikationen**   Winget / Chocolatey + JSON-Manifest    Manifest-gesteuert, hypervisorunabhängig
  **Schicht 8 -- DEX/Monitoring**  ControlUp · uberagent                  Agent im Image, Config via GPO

> **WICHTIG** Sysprep wird für MCS-Deployments NICHT benötigt. Citrix MCS verwaltet Maschinenidentitäten (SID, Hostname, Domain-Join) eigenständig.

# 1 Vision und Zielsetzung

## 1.1 Was ist Vendor Independence Day?

Vendor Independence Day beschreibt den Zustand einer IT-Infrastruktur, in der kein einzelner Technologiehersteller eine kritische Abhängigkeit darstellt. Jede Schicht der Infrastruktur kann durch ein alternatives Produkt ersetzt werden, ohne dass dies einen Totalrückbau erfordert. VID ist damit kein Produkt, sondern ein Architekturprinzip und ein Reifegradmodell.

## 1.2 Designprinzipien

-   **Schichttrennung (Separation of Concerns):** Jede Schicht hat genau eine Verantwortung. Schichten kommunizieren über definierte Schnittstellen.

-   **Wiederholbarkeit (Repeatability):** Jede Schicht wird vollständig automatisiert gebaut und kann jederzeit neu erstellt werden.

-   **Dokumentierter Austausch (Documented Exchangeability):** Für jede Schicht existiert ein alternativer Anbieter sowie ein schriftlicher Austauschplan.

-   **Infrastructure as Code (IaC):** Packer, Terraform und PowerShell beschreiben die gesamte Umgebung deklarativ.

-   **Least Hypervisor Coupling:** Das Guest OS (Schicht 5) enthält keine hypervisorspezifischen Komponenten. Treiber werden in Schicht 6 isoliert.

-   **Applikationsportabilität:** Anwendungen werden über ein einheitliches Manifest ausgeliefert und sind von der Plattform entkoppelt.

## 1.3 Abgrenzung und Scope

Diese Dokumentation beschreibt Phase 1 von VID. Folgende Annahmen gelten:

-   Ein VMware vSphere-Cluster mit vCenter ist bereits installiert und konfiguriert.

-   Eine Active Directory Domain ist vorhanden und erreichbar.

-   Citrix DaaS (Cloud) ist als Delivery-Plattform konfiguriert.

-   Citrix Cloud Connectors sind im Resource Location deployed.

-   Als zweite Hypervisor-Option wird Citrix Hypervisor (XenServer) + XenCenter betrachtet.

Nicht im Scope von Phase 1:

-   Schicht 1 (Hardware), Schicht 2 (Hypervisor-Betrieb), Schicht 3 (Hypervisor-Management)

-   Schicht 4 (Active Directory / Entra ID) -- Annahme: vorhanden und funktionsfähig

-   Azure Local als Hypervisor-Plattform (vorgesehen für Phase 2)

-   EntraID-only Szenarien (vorgesehen für Phase 3)

# 2 Das 8-Schichten-Modell

Das VID-Referenzarchitekturmodell definiert acht klar voneinander getrennte Schichten. Jede Schicht ist technologisch austauschbar. Die folgende Tabelle gibt einen Überblick über alle acht Schichten, ihre Verantwortlichkeiten und die jeweils unterstützten Technologien.

  **\#**   **Schicht**             **Verantwortung**                     **Technologien (Beispiele)**
  -------- ----------------------- ------------------------------------- -------------------------------------------------------
  **1**    Hardware                Server, Netzwerk, Storage             HPE, Dell, Cisco, NetApp, \...
  **2**    Hypervisor              Virtualisierungsplattform             VMware vSphere, Citrix Hypervisor, Azure Local
  **3**    Hypervisor-Management   Orchestrierung, Provisioning          vCenter, XenCenter, WAC, Terraform
  **4**    Directory Services      Identität & Zugang                    Active Directory, Microsoft Entra ID
  **5**    Windows 11 VM           Gast-Betriebssystem                   W11 Pro/Enterprise (Packer-Build)
  **6**    Treiber                 Hypervisor-Guest-Integration          VMware Tools, Citrix VM Tools
  **7**    Applikationen           Business-Anwendungen + VDA + Profile  Office 365, SAP, Citrix VDA, FSLogix/CPM
  **8**    DEX / Monitoring        Digital Employee Experience           ControlUp, uberagent, Nexthink, SysTrack

## 2.1 Schichtabhängigkeiten und Interfaces

Schichten kommunizieren ausschließlich über definierte, standardisierte Schnittstellen. Eine Schicht darf keine direkten Kenntnisse über die interne Implementierung der benachbarten Schicht haben.

-   **Schicht 5 → 6:**Schicht 5 (W11) definiert, WELCHE Treiber benötigt werden (SCSI, NIC, Display). Schicht 6 liefert die hypervisorspezifische Implementierung.

-   **Schicht 6 → 5:**Schicht 6 registriert Treiber im OS -- das OS kennt keinen Hypervisor direkt.

-   **Schicht 7 → 5+6:**Applikationen nutzen Windows-APIs. Sie sind blind gegenüber Hypervisor und Treibern.

-   **Schicht 5 → 4:**Domain-Join und Gruppenrichtlinien kommen aus Schicht 4. Das Image enthält keine hardcodierten AD-Einstellungen.

# 3 Schicht 5: Windows 11 Master Image

## 3.1 Konzept: Hypervisor-agnostisches Base Image

Das Windows 11 Base Image (Schicht 5) wird mit HashiCorp Packer gebaut und ist vollständig hypervisor- und broker-agnostisch. Es enthält weder Hypervisor-spezifische Treiber (Schicht 6) noch Broker-Agenten wie den Citrix VDA (Schicht 7).

Dadurch kann dasselbe Layer-5-Image als Basis für VMware- und XenServer-Deployments sowie für verschiedene Broker-Plattformen (Citrix, AVD, Horizon) genutzt werden. Nur der Packer-Builder-Typ (Schicht 6) und die VDA-Installation (Schicht 7) unterscheiden sich.

## 3.2 Packer Build-Schritte Layer 5 (Golden Image)

Die folgenden Schritte erzeugen ein reines, broker-agnostisches Windows 11 Base Image. Hypervisor-Treiber (Schicht 6) werden durch die iso_paths-Konfiguration automatisch eingebunden.

1.  **Schritt 1 -- Installation \[Layer 5\]:** Windows 11 unattended Setup via autounattend.xml. EFI, PVSCSI, TPM, Deutsch/Englisch konfiguriert.

2.  **Schritt 2 -- OS Baseline \[Layer 5\]:** windows-prepare.ps1: TLS-Härtung, Explorer-Einstellungen, Passwort-Policy.

3.  **Schritt 3 -- Windows Updates \[Layer 5\]:** Vollständige Installation aller aktuellen Windows Updates via windows-update Provisioner inkl. automatischer Neustarts.

4.  **Schritt 4 -- Export \[Layer 5\]:** Übertragung des reinen OS-Images in vSphere Content Library oder XenServer SR als Basis-Template.

> **VID-PRINZIP** Das Layer-5-Image enthält keinen VDA, keinen Broker-Agenten und keine anwendungsspezifischen Konfigurationen. Es ist das austauschbare Fundament für alle darüber liegenden Schichten.

Die VDA-Installation und alle weiteren Layer-7-Schritte sind in Kapitel 5 (Schicht 7) beschrieben.

## 3.3 Dateistruktur

  **Pfad**                                              **Beschreibung**
  ----------------------------------------------------- -------------------------------------------------------
  packer/windows/desktop/11/windows.pkr.hcl             VMware vSphere Build-Definition (vsphere-iso Builder)
  packer/windows/desktop/11/variables.pkr.hcl           Variablendefinitionen inkl. VID-Data Variablen (vid_data_datastore, vid_data_path, vid_vda_installer)
  packer/windows/desktop/11/windows.auto.pkrvars.hcl    Werte für W11 + VID-Data Konfiguration (datastore2/VID-Data)
  packer/windows/desktop/11-xenserver/windows.pkr.hcl   XenServer Build-Definition (xenserver-iso Builder)
  packer/config/vsphere.pkrvars.hcl                     vSphere Connection (Endpoint, Credentials)
  packer/config/build.pkrvars.hcl                       Build-User-Credentials
  packer/config/common.pkrvars.hcl                      Gemeinsame Einstellungen (Content Library, Timeouts)
  packer/create\_templates.sh                           Build-Script: ./create\_templates.sh w11-vda

## 3.4 VID-Data Repository

Das VID-Data Repository ist der zentrale Ablageort für alle Build-Artefakte, die nicht Teil des Betriebssystems sind: VDA-Installer, zusätzliche Treiberpakete, DEX-Agenten und App-Installer. Die Trennung von OS-Image und Installer-Dateien ist ein VID-Kernprinzip -- Installer werden zur Buildzeit aus dem Repository gezogen, nicht fest ins Image eingebaut.

**SMB Share (aktiv -- Hypervisor-agnostisch)**

Ein zentraler Windows-Fileserver-Share dient als VID-Data Repository. Die Ordnerstruktur ist für alle Kunden identisch -- nur der Inhalt (Installer-Versionen) unterscheidet sich. Da die Packer-VM beim Build noch nicht domain-joined ist, werden die Credentials explizit als Packer-Variablen übergeben; kein AD-Beitritt erforderlich.

```
\\fileserver.domain.local\VID-Data\
  ├── citrix\
  │   ├── vda\                    ← VDA-Installer (Layer 7a)  ← AKTIV
  │   └── optimize\               ← optionale Custom-Optimize-Skripte
  ├── microsoft\
  │   ├── avd\                    ← AVD Agent (Phase 3)
  │   └── fslogix\                ← FSLogix (Phase 2+)
  ├── vmware\
  │   └── horizon\                ← Horizon Agent (optional)
  ├── dex\
  │   ├── controlup\              ← ControlUp Agent (Layer 8, später)
  │   └── uberagent\              ← uberagent (Layer 8, später)
  ├── drivers\
  │   ├── vmware\                 ← zusätzliche VMware-Treiber (falls nötig)
  │   └── xenserver\              ← zusätzliche XenServer-Treiber (falls nötig)
  └── apps\                       ← Business App Installer (Layer 7c)
```

Packer-Variablen:

  **Variable**           **Wert (Beispiel)**                  **Beschreibung**
  ---------------------- ------------------------------------ --------------------------------------------------
  vid_smb_server         fileserver.vdi-experts.de            Hostname oder IP des Fileservers
  vid_smb_share          VID-Data                             Share-Name
  vid_smb_username       DOMAIN\\svc-packer                   Serviceaccount mit Lesezugriff auf den Share
  vid_smb_password       (sensitiv)                           Passwort -- in Produktion: Vault oder Secret-Store
  vid_vda_installer      VDAWorkstationSetup.exe              Dateiname in citrix\\vda\\

Der VDA-Installer wird automatisch aus `\\<vid_smb_server>\VID-Data\citrix\vda\<vid_vda_installer>` kopiert.

**Fallback -- vSphere Datastore Browser**

Als Rückfalloption kann der Installer alternativ über die vCenter HTTPS Datastore Browser API bezogen werden (Variablen: `VCENTER_URL`, `VID_DATASTORE`, `VID_PATH` als auskommentierte env vars in `windows.pkr.hcl`). Diese Option ist vSphere-spezifisch und entspricht nicht dem VID-Multi-Hypervisor-Prinzip.

> **VID-PRINZIP** Installer-Dateien gehören nicht ins Image. Sie werden zur Buildzeit aus einem zentralen SMB Repository bezogen. Der VDA-Installer kann jederzeit durch Ablegen einer neuen Datei in `citrix\vda\` aktualisiert werden -- ohne OS-Image-Rebuild.

# 4 Schicht 6: Treiber-Abstraktion

Schicht 6 bildet die Brücke zwischen dem Gast-Betriebssystem (Schicht 5) und dem Hypervisor (Schicht 2). Sie enthält ausschließlich hypervisorspezifische Treiber und Guest-Tools. Das Schlüsselprinzip: Schicht 5 ist blind gegenüber dem Hypervisor -- Schicht 6 wird zur Laufzeit (Packer-Build) dynamisch zusammengestellt.

## 4.1 Hypervisor-Erkennungsmechanismus

Das Skript windows-detect-hypervisor.ps1 erkennt den Hypervisor automatisch über drei Erkennungsstufen und delegiert anschließend an das passende Installationsskript:

  **Priorität**      **Erkennungsmethode**                                     **Erkannte Signatur**
  ------------------ --------------------------------------------------------- ----------------------------------------------
  **1 (primär)**     WMI -- Win32\_BIOS / Win32\_ComputerSystem                Manufacturer enthält \'VMware\' oder \'Xen\'
  **2 (sekundär)**   Registry -- HKLM:\\SOFTWARE\\Microsoft\\Virtual Machine   HostName enthält \'vmware\'
  **3 (Fallback)**   PCI-Geräteliste -- Win32\_PnPEntity                       Geräte VMXNET, PVSCSI, XenBus erkannt

## 4.2 VMware vSphere -- Treiber-Stack

-   **PVSCSI (Paravirtual SCSI):** High-Performance Storage-Controller. Deutlich geringere CPU-Last als LSI Logic.

-   **VMXNET3 (Paravirtual NIC):** 10 GbE-Performance in VMs. RSS, LRO, TSO unterstützt.

-   **VMware SVGA II:** Virtueller Display-Adapter mit VMware Tools DirectX-Support.

-   **VMware Tools Service:** Heartbeat, Snapshot-Synchronisation, Guest-Customization-Unterstützung.

-   **VMware vTPM:** Virtuelles TPM 2.0 für Windows 11 Secure Boot-Anforderungen.

Installationsskript: packer/scripts/windows/windows-vmtools.ps1

## 4.3 Citrix Hypervisor (XenServer) -- Treiber-Stack

-   **XenVbd (PV Block Device):** Paravirtual Storage-Treiber. Ersetzt emulierte IDE-Controller.

-   **XenNet (PV Network):** Paravirtual Netzwerktreiber. Eliminiert emulierte E1000-NIC.

-   **XenBus (PV Bus):** Übergeordneter PV-Bus, über den XenVbd und XenNet kommunizieren.

-   **XenGfx (Graphics):** Virtueller Grafiktreiber für Xen-Umgebungen.

-   **Citrix Management Agent:** Monitoring, SR-IOV, Guest-Metrics, Live-Migration-Unterstützung.

Installationsskripte: windows-xenserver-tools.ps1 / windows-detect-hypervisor.ps1

## 4.4 Abhängigkeit Layer 6 → Layer 7

Der Citrix VDA (Schicht 7) hat technische Abhängigkeiten zu den Hypervisor-Treibern (Schicht 6), insbesondere zu den HDX-fähigen Display- und Netzwerktreibern. Die Installationsreihenfolge im Packer-Build ist daher fix: Schicht 6 (Treiber) muss vor Schicht 7 (VDA) abgeschlossen sein.

Das Layer-5-Image (reines OS) bleibt dabei vollständig frei von VDA-Komponenten. Der VDA wird erst im Layer-7-Build-Schritt auf das fertige Layer-5+6-Image aufgebracht.

> **VDA BUILD-TIPP** VDA-Parameter /mastermcsimage verhindert, dass der VDA im Build-Prozess versucht, sich bei einem Delivery Controller zu registrieren. Die Registrierung erfolgt erst auf den durch MCS provisionierten Maschinen über den Cloud Connector.

# 5 Schicht 7: Applikationsschicht

Schicht 7 umfasst den Broker-Agenten (VDA), das Profil-Management und alle Business-Anwendungen. Sie wird auf das fertige Layer-5+6-Image aufgebracht und ist vollständig austauschbar ohne OS-Rebuild.

## 5.0 Packer Build-Schritte Layer 7 (Customization)

Diese Schritte werden nach den Layer-5-Schritten (Kapitel 3.2) im selben Packer-Lauf ausgeführt. Sie setzen ein vollständig gepatchtes Layer-5-Image mit installierten Layer-6-Treibern voraus.

1.  **Schritt 5 -- Citrix VDA \[Layer 7a – Broker Agent\]:** windows-citrix-vda.ps1: VDA-Installer wird zur Buildzeit aus dem VID-Data Repository bezogen (Phase 1: vCenter Datastore Browser API von `[datastore2] VID-Data/`; Phase 2+: SMB Share). Stiller Install mit /mastermcsimage. Kein Controller-Lookup im Build. Austauschbar gegen AVD Agent, Horizon Agent etc.

2.  **Schritt 6 -- Neustart \[Layer 7a\]:** Zwingend nach VDA-Installation für vollständige Treiberintegration.

3.  **Schritt 7 -- Post-VDA Updates \[Layer 7a\]:** Zweiter Windows-Update-Lauf für VDA-induzierte Komponenten.

4.  **Schritt 8 -- Optimierungen \[Layer 7a+7b\]:** windows-citrix-optimize.ps1: VDI-Tuning (Services, Tasks, Telemetrie, AppX, Netzwerk, NTFS).

5.  **Schritt 9 -- MCS Prep \[Layer 7\]:** windows-citrix-mcs-prep.ps1: Temp-Cleanup, DISM, kein Sysprep. VMs erhalten Identität (SID, Hostname) durch MCS.

6.  **Schritt 10 -- Export \[Layer 7\]:** Fertiges MCS-Master-Image in vSphere Content Library oder XenServer SR.

> **VID-PRINZIP** Layer 5 und Layer 7 sind konzeptionell getrennte Build-Phasen – auch wenn sie im gleichen Packer-Lauf ausgeführt werden. In einer späteren Ausbaustufe können beide Phasen in separate Packer-Builds aufgeteilt werden, sodass das Layer-5-Image als universelle Basis für mehrere Layer-7-Varianten dient.

## 5.1 Phase 1: Skriptbasierter Ansatz

In Phase 1 werden Anwendungen über ein JSON-Manifest (apps-manifest.json) und das Installations-Framework (windows-apps-install.ps1) bereitgestellt. Das Framework unterstützt:

-   Winget (Windows Package Manager) als primären Installationsweg

-   Chocolatey als Fallback für Pakete, die nicht im Winget-Store verfügbar sind

-   Pro-App und Pro-Gruppe aktivierbare/deaktivierbare Einträge im Manifest

-   DryRun-Modus zur Validierung ohne tatsächliche Installation

-   Ausführbar während Packer-Build (Einbakierung) ODER bei VM-Erststart (post-provisioning)

## 5.2 Applikations-Manifest (apps-manifest.json)

Das Manifest ist das zentrale Steuerungselement für Schicht 7. Es ist hypervisorunabhängig und kann für VMware- und XenServer-Images identisch verwendet werden.

  **Gruppe**                 **Anwendungen (Beispiele)**                                **Status Phase 1**
  -------------------------- ---------------------------------------------------------- -----------------------------
  **Runtime Environments**   Microsoft VC++ Redistributable, .NET 8 Runtime             Aktiv
  **Produktivität**          7-Zip, Adobe Reader, Notepad++, Microsoft 365              Aktiv (M365 optional)
  **Webbrowser**             Microsoft Edge (Enterprise), Google Chrome                 Edge aktiv, Chrome optional
  **Security Tools**         Npcap                                                      Deaktiviert (optional)
  **IT Tools**               Sysinternals Suite, WinSCP                                 Deaktiviert (optional)

## 5.3 Roadmap: Erweiterte App-Delivery (Phase 2+)

In Phase 2 wird der skriptbasierte Ansatz um weitere herstellerunabhängige Delivery-Mechanismen erweitert. Mögliche Optionen:

-   **Microsoft Intune / WinGet:** Cloud-basierte App-Delivery ohne on-premises Infrastruktur

-   **MSIX App Attach:** Microsoft-nativer App-Delivery-Mechanismus für AVD und W365

-   **Weitere Paketmanager:** Chocolatey Business, Scoop oder eigene interne Repositories

# 6 Build-Pipeline und MCS-Deployment

## 6.1 Gesamtübersicht: Packer → vSphere → Citrix DaaS

Die gesamte Build- und Deployment-Pipeline ist vollständig automatisiert und versioniert. Folgende Schritte bilden den Workflow von der Packer-Initiation bis zur Benutzerbereitstellung:

1. **1. Packer Build starten:** cd packer && ./create\_templates.sh w11-vda

2. **2. W11 unattended Install:** autounattend.xml, VMware Tools, WinRM-Init

3. **3. OS Baseline + Updates:** windows-prepare.ps1 → Windows Update (alle Patches)

4. **4. Citrix VDA Install:** windows-citrix-vda.ps1 (/mastermcsimage, /quiet, /noreboot)

5. **5. Optimierungen:** windows-citrix-optimize.ps1 (18 Bereiche, AppX-Cleanup)

6. **6. MCS Prep:** windows-citrix-mcs-prep.ps1 (kein Sysprep! Temp-Cleanup, DISM)

7. **7. Template-Export:** Packer überträgt VM in vSphere Content Library (euc-demo-lib)

8. **8. Snapshot für MCS:** In vCenter: VM-Snapshot als MCS-Ausgangspunkt erstellen

9. **9. Citrix MCS Catalog:** deploy-citrix-mcs.ps1: Machine Catalog aus VM-Snapshot

10. **10. VMs provisionieren:** MCS klont VMs, joined Domain, setzt SIDs, benennt Hosts

11. **11. Delivery Group:** Delivery Group erstellen, User-Gruppen zuweisen

12. **12. Benutzer erhält Desktop:** Citrix DaaS stellt W11-Desktop über HDX bereit

## 6.2 Build-Skript Verwendung

Das Build-Skript create\_templates.sh unterstützt selektive Builds:

  **Befehl**                          **Funktion**
  ----------------------------------- ---------------------------------------------
  ./create\_templates.sh              Baut alle Templates (W11 VDA + Server 2022)
  ./create\_templates.sh w11-vda      Nur Windows 11 + Citrix VDA (VMware)
  ./create\_templates.sh server2022   Nur Windows Server 2022 Templates

## 6.3 MCS-Deployment-Skript

Das Skript citrix-mcs/deploy-citrix-mcs.ps1 automatisiert den MCS-Deployment-Schritt vollständig über die Citrix DaaS Remote PowerShell SDK:

-   Authentifizierung gegen Citrix Cloud (Secure Client API Key)

-   Erstellt oder aktualisiert einen Machine Catalog (MCS-Provisioning-Scheme)

-   Erstellt AD-Computer-Konten und provisioniert VMs

-   Erstellt oder aktualisiert Delivery Group und weist AD-Gruppen zu

-   Unterstützt -WhatIf Dry-Run für Validierungsläufe

Beispielaufruf:

> .\\deploy-citrix-mcs.ps1 \`\
> -CitrixClientId \'YOUR\_API\_KEY\' \`\
> -CitrixClientSecret \'YOUR\_SECRET\' \`\
> -CustomerId \'YOUR\_CUSTOMER\_ID\' \`\
> -MasterImageVM \'XDHyp:\\Connections\\vSphere\\\...\\vm.vm\\snap.snapshot\' \`\
> -CatalogName \'W11-Citrix-VDA-MCS\' \`\
> -VmCount 10 \`\
> -UserGroups \'DOMAIN\\Citrix-Desktop-Users\'

# 7 Vergleich: VMware vSphere vs. Citrix Hypervisor

Beide Hypervisoren sind vollständig in das VID-Framework integriert. Die folgende Matrix zeigt die technischen Unterschiede, die für die Schichten 5, 6 und 7 relevant sind.

  **Kriterium**                **VMware vSphere**                 **Citrix Hypervisor (XenServer)**
  ---------------------------- ---------------------------------- ------------------------------------------
  **Packer-Builder**           vsphere-iso (HashiCorp offziell)   xenserver-iso (Community Plugin)
  **Schicht-6-Treiber**        VMware Tools (PVSCSI, VMXNET3)     Citrix VM Tools (XenBus, XenNet, XenVbd)
  **Treiber-Erkennung**        WMI: Manufacturer = \'VMware\'     WMI: Manufacturer = \'Xen\' / PCI XenBus
  **vTPM / Secure Boot**       Ja (vSphere 7+, efi-secure)        Ja (XenServer 8+)
  **MCS-Unterstützung**        Vollständig (Citrix DaaS)          Vollständig (Citrix DaaS)
  **Content Library / SR**     vSphere Content Library            XenServer Storage Repository (SR)
  **Template-Format**          VM Template oder OVF               VM Template (XVA-Format)
  **Citrix VDA Support**       Vollständig (CURRENT/LTSR)         Vollständig (CURRENT/LTSR)
  **VID-Status Phase 1**       Primär / Produktionsreif           Sekundär / bereit (Community-Plugin)
  **Management-Integration**   vCenter (Terraform/Packer)         XenCenter (Packer xenserver-iso)
  **HDX EDT (UDP)**            Unterstützt (VMXNET3)              Unterstützt (XenNet)
  **Open-Source-Option**       Nein (kommerzielle Lizenz)         Ja: XCP-ng + Xen Orchestra (Phase 2)

> **VID-KERNAUSSAGE** Das VID-Framework stellt sicher, dass ein Wechsel von VMware zu Citrix Hypervisor (oder umgekehrt) keine Änderungen an Schicht 5 (OS-Image) oder Schicht 7 (Applikationen) erfordert. Lediglich der Packer-Builder-Typ und das Schicht-6-Skript unterscheiden sich.

# 8 Schicht 8: DEX / Monitoring

## 8.1 Konzept: Digital Employee Experience als eigene Schicht

Schicht 8 erfasst die Benutzererfahrung (Digital Employee Experience, DEX) und die Infrastrukturüberwachung vollständig unabhängig von den darunterliegenden Schichten. DEX-Agenten werden im Master Image installiert (via Packer, Layer 8-Schritt), jedoch **niemals mit hartcodierten Serverkonfigurationen**. Verbindungsparameter (Collector-Adressen, Lizenzserver, Tags) werden ausschließlich über Gruppenrichtlinien (Schicht 4) oder Konfigurationsdateien pro Umgebung verteilt.

**Warum eine eigene Schicht?**

- DEX-Tools sind plattformunabhängig und laufen auf VMware- und XenServer-Images identisch
- Sie können ohne OS-Rebuild oder VDA-Neuinstallation ausgetauscht werden (ControlUp → uberagent → Nexthink)
- Monitoring-Daten dürfen keine Auswirkung auf den Image-Build-Prozess haben
- Lizenz- und Infrastrukturabhängigkeiten bleiben außerhalb des Images

## 8.2 ControlUp

ControlUp ist eine DEX-Plattform, die Echtzeit-Sitzungsanalyse, proaktive Remediation und historische Trendanalyse für virtuelle Desktops und physische Endgeräte bietet.

**Komponenten im VID-Kontext:**

  **Komponente**            **Funktion**                                                **VID-Layer**
  ------------------------- ----------------------------------------------------------- ---------------
  ControlUp Agent           Echtzeit-Monitoring auf der VDA-Maschine                    Layer 8 (Image)
  ControlUp Monitor         Zentraler Datenaggregator (On-Premises oder Cloud)          Layer 3 (Infra)
  ControlUp Console/Edge    Management-UI und Automatisierungs-Engine                   Layer 3 (Infra)
  Scoutbees                 Synthetische Monitoring-Transaktionen (proaktiv)            Layer 3 (Infra)
  Real-time DX              Session-Analyse, Score-basierte UX-Bewertung                Layer 8

**Silent Installation:**

```powershell
# ControlUp Agent – Silent Install
# Installer: CUAgent.exe (von ControlUp Support-Portal)
CUAgent.exe /S /v"/qn MONITOR=<monitor-server-fqdn>"

# Oder via MSI:
msiexec /i CUAgent.msi /quiet /norestart MONITOR="<monitor-server-fqdn>"
```

**VID-Prinzip:** `MONITOR=<server>` wird **nicht** ins Image geschrieben. Der Agent wird ohne Serverkonfiguration installiert; die Verbindung zum Monitor-Server erfolgt über GPO (`HKLM\SOFTWARE\Smart-X\ControlUp\Agent`).

## 8.3 uberagent

uberagent (von vastlimits, jetzt Citrix uberagent) ist ein leichtgewichtiger Monitoring-Agent für Windows-Endgeräte und VDAs, der Sitzungsleistung, Anwendungsresponsezeiten, Netzwerklatenz und Sicherheitsereignisse erfasst. Die Daten werden an ein SIEM/Analyse-Backend (Splunk, Elasticsearch, Azure Monitor) übermittelt.

**Komponenten im VID-Kontext:**

  **Komponente**              **Funktion**                                                **VID-Layer**
  --------------------------- ----------------------------------------------------------- ---------------
  uberagent (Windows Service) Datenerfassung auf der VDA/Endpoint-Maschine               Layer 8 (Image)
  uberagent.conf              Konfigurationsdatei (Backend, Metriken, Sampling-Rate)     Layer 4 (GPO)
  Splunk / Elasticsearch      Datenspeicher und Analyse-Backend                          Layer 3 (Infra)
  uberagent ESA               Endpoint Security Analytics (UEBA, Threat Detection)       Layer 8 (Image)

**Silent Installation:**

```powershell
# uberagent – Silent Install via MSI
msiexec /i uberagent.msi /quiet /norestart

# uberagent ESA (Security Analytics) – separates MSI
msiexec /i uberagentESA.msi /quiet /norestart
```

**Konfiguration:** Die `uberagent.conf` wird **nicht** ins Image eingebettet. Sie wird über GPO-Skripte oder SYSVOL-Shares bei der VM-Provisionierung verteilt. Alternativ: Deployment via Citrix WEM (Workspace Environment Management) oder Intune.

## 8.4 Vergleich ControlUp vs. uberagent

  **Kriterium**              **ControlUp**                               **uberagent**
  -------------------------- ------------------------------------------- ------------------------------------------
  **Schwerpunkt**            Echtzeit-Session-Management + Remediation   Langzeit-Analytics + Security (UEBA)
  **Backend**                ControlUp Cloud / On-Prem Monitor           Splunk, Elasticsearch, Azure Monitor
  **Echtzeit-Eingriff**      Ja (Kill-Process, Logoff, Script-Run)       Nein (reine Datenspeicherung)
  **Citrix-Integration**     Nativer Citrix DaaS/CVAD Support            Nativer Citrix HDX-Insight
  **VDA-spezifische Daten**  Session Latency, Logon Duration, ICA RTT    App Response Time, Logon Steps, Protocol
  **Lizenzmodell**           Per Named User oder Concurrent              Per Endpoint / Per User
  **Image-Footprint**        Agent ~15 MB                                Agent ~8 MB
  **VID-Austauschbarkeit**   Hoch (Agent austauschbar ohne OS-Rebuild)   Hoch (Agent austauschbar ohne OS-Rebuild)
  **Empfehlung VID**         Primär für Ops-Teams (Echtzeit-Reaktion)   Primär für Analytics (Trend, Security)

> **EMPFEHLUNG** Beide Tools schließen sich nicht aus. ControlUp für operatives Echtzeit-Monitoring und proaktive Remediation, uberagent für historische Trendanalyse und Security-Visibility. Im VID-Kontext werden beide als Layer-8-Agenten im Image installiert und können unabhängig voneinander aktiviert, deaktiviert oder ersetzt werden.

## 8.5 Voraussetzungen (Vorher-Modell Layer 8)

  **Voraussetzung**                                           **Verantwortung**
  ----------------------------------------------------------- ------------------
  ControlUp Monitor oder ControlUp Cloud-Account vorhanden    Infra-Team
  uberagent-Backend (Splunk/Elastic) konfiguriert             Analytics-Team
  Lizenz für gewähltes DEX-Tool beschafft                     Management
  GPO für Agent-Konfiguration (Server, Tags, Lizenz) erstellt Schicht 4 / AD
  Firewall-Freigaben für Agent → Backend-Kommunikation        Netzwerk-Team
  DEX-Tool im Packer-Build aktiviert (Variable gesetzt)       Build-Team

# 9 Roadmap

  **Phase**     **Schichten**   **Inhalte**                                                                          **Status**
  ------------- --------------- ------------------------------------------------------------------------------------ ------------
  **Phase 1**   5, 6, 7, 8      W11 + VDA (VMware + XenServer), Treiber-Abstraktion, App-Manifest, DEX-Agenten       In Arbeit
  **Phase 1b**  3               Citrix DaaS Infrastruktur via Terraform (Kataloge, Delivery Groups, Policies)         Geplant (nach Phase 1)
  **Phase 2**   2, 3            Hypervisor-Ebene: Azure Local hinzufügen, Terraform für Hypervisor-Mgmt              Geplant
  **Phase 3**   4               Entra ID (Pure Cloud) als Alternative zu Active Directory                            Geplant
  **Phase 4**   7               Erweiterte App-Delivery: Intune / MSIX App Attach / weitere Paketmanager             Geplant
  **Phase 5**   1               Hardware-Abstraktion: Bare Metal provisioning (Redfish/Ansible)                      Vision
  **Phase 6**   alle            VID Compliance-Score, automatisiertes Schichten-Audit                                Vision

## 8.0 Voraussetzungen für Phase 1b (Terraform Citrix DaaS)

-   Citrix DaaS Tenant verfügbar (Cloud Connector installiert, Resource Location konfiguriert)

-   Citrix Terraform Provider eingerichtet (`registry.terraform.io/providers/citrix/citrix`)

-   Service Principal / API Client in Citrix Cloud angelegt (Client ID + Secret)

-   Packer-Build (Phase 1) liefert fertiges MCS-Master-Image in vSphere Content Library

-   Terraform ersetzt schrittweise die bestehenden Skripte `deploy-citrix-mcs.ps1` und `update-image.ps1`

**Geplante Terraform-Ressourcen:** `citrix_machine_catalog`, `citrix_delivery_group`, `citrix_policy_set`, `citrix_zone`, `citrix_vsphere_hypervisor_resource_pool`

> **Abgrenzung Packer / Terraform:** Packer baut das Image (Layer 5--7). Terraform verwaltet die Citrix DaaS Infrastruktur (Schicht 3: Maschinenkataloge, Delivery Groups, Policies). Kein Overlap, klare Verantwortlichkeiten.

## 8.1 Voraussetzungen für Phase 2

-   Azure Local (ehemals Azure Stack HCI) Cluster verfügbar oder geplant

-   Terraform Provider für Azure Local / HCI verfügbar

-   Citrix DaaS Resource Location in Azure/Azure Local konfiguriert

-   Packer-Plugin für Azure Local evaluiert

## 8.2 Voraussetzungen für Phase 4 (Erweiterte App-Delivery)

-   Anwendungsinventar vollständig dokumentiert (Basis für Delivery-Entscheidung)

-   Entscheidung über primären Delivery-Mechanismus (Intune, MSIX App Attach, Paketmanager)

-   Test-Prozess für App-Updates und Rollbacks definiert

# 9 Anhang: Technische Referenz

## 9.1 Vollständige Dateiliste (VID Phase 1)

  **Datei**                                                **Schicht**   **Funktion**
  -------------------------------------------------------- ------------- -----------------------------------------------------------------
  packer/windows/desktop/11/windows.pkr.hcl                5             VMware Build-Definition mit Citrix VDA Provisioner-Kette
  packer/windows/desktop/11/variables.pkr.hcl              5             Alle Variablen inkl. VID-Data Variablen (vid_data_datastore, vid_data_path, vid_vda_installer)
  packer/windows/desktop/11/windows.auto.pkrvars.hcl       5             W11-spezifische Werte + VID-Data Konfiguration (datastore2/VID-Data)
  packer/windows/desktop/11/data/autounattend.pkrtpl.hcl   5             Windows 11 unattended Setup (EFI, Deutsch-Tastatur, Build-User)
  packer/windows/desktop/11-xenserver/windows.pkr.hcl      5+6           XenServer Build-Definition (xenserver-iso Plugin)
  packer/windows/desktop/11-xenserver/variables.pkr.hcl    5+6           XenServer-spezifische Variablen
  packer/scripts/windows/windows-init.ps1                  6             WinRM-Initialisierung für Packer-Kommunikation
  packer/scripts/windows/windows-vmtools.ps1               6             VMware Tools Installation mit Retry-Logik
  packer/scripts/windows/windows-detect-hypervisor.ps1     6             VID: Hypervisor-Erkennung + automatische Tool-Auswahl
  packer/scripts/windows/windows-xenserver-tools.ps1       6             Citrix VM Tools Installation für XenServer
  packer/scripts/windows/windows-prepare.ps1               5             OS Baseline: TLS, RDP, Explorer, Passwort-Policy
  packer/scripts/windows/windows-citrix-vda.ps1            5             Citrix VDA silent install (/mastermcsimage)
  packer/scripts/windows/windows-citrix-optimize.ps1       5             VDI-Optimierungen (18 Bereiche, AppX-Cleanup)
  packer/scripts/windows/windows-citrix-mcs-prep.ps1       5             MCS-Vorbereitung (kein Sysprep, Cleanup, DISM)
  packer/scripts/windows/windows-sysprep.ps1               5             Sysprep (nur für PVS/manuelle Duplikation, NICHT MCS)
  packer/scripts/windows/windows-apps-install.ps1          7             App-Framework: Winget + Chocolatey, JSON-Manifest-gesteuert
  packer/scripts/windows/apps-manifest.json                7             Anwendungskatalog mit Gruppe/App/Hypervisor-Unabhängigkeit
  citrix-mcs/deploy-citrix-mcs.ps1                         MCS           Citrix DaaS MCS: Catalog, VMs, Delivery Group, User-Zuweisung
  packer/create\_templates.sh                              CI            Build-Script: w11-vda, server2022, oder beides
  packer/config/vsphere.pkrvars.hcl                        Cfg           vSphere Endpoint + Credentials
  packer/config/build.pkrvars.hcl                          Cfg           Build-User Credentials
  packer/config/common.pkrvars.hcl                         Cfg           Content Library, Timeouts, ISO-Datastore

## 9.2 Voraussetzungen und benötigte Lizenzen

**Software auf dem Packer Build-Host (Linux / WSL):**

-   **HashiCorp Packer \>= 1.9.1:** Kostenlos / Open Source

-   **Packer Plugin: vsphere:** Kostenlos (HashiCorp) -- `packer init` lädt das Plugin automatisch

-   **Packer Plugin: windows-update:** Kostenlos (Community: rgl)

-   **Packer Plugin: xenserver-iso:** Kostenlos (Community: xenserver)

-   **xorriso:** Pflicht -- wird von Packer zur Erstellung virtueller CD-Images (Treiber-CD im Build) benötigt

    ```bash
    # Debian / Ubuntu / WSL
    sudo apt-get install -y xorriso

    # RHEL / Rocky / AlmaLinux
    sudo dnf install -y xorriso
    ```

    Alternativ: `genisoimage` (stellt `mkisofs` bereit -- ebenfalls von Packer akzeptiert)

    ```bash
    sudo apt-get install -y genisoimage
    ```

    > **HINWEIS** Fehlt `xorriso`, bricht Packer sofort mit der Meldung *"could not find a supported CD ISO creation command"* ab -- noch bevor die VM erstellt wird.

**Lizenzen:**

-   **Citrix DaaS (Cloud):** Lizenzpflichtig (pro Named User oder CCU)

-   **Citrix VDA:** In Citrix DaaS Lizenz enthalten

-   **VMware vSphere + vCenter:** Lizenzpflichtig (Broadcom)

-   **Citrix Hypervisor (XenServer):** Kostenlos (Basis) / Lizenzpflichtig (Premium)

-   **Windows 11 Pro/Enterprise:** Microsoft Lizenz erforderlich (KMS oder MAK)

-   **PowerShell 5.1+ / 7+:** Kostenlos (in W11 enthalten)

-   **Citrix DaaS Remote PS SDK:** Kostenlos (von Citrix bereitgestellt)

# 10 Schicht 4: Active Directory / Identity Provider

Schicht 4 ist die Identitäts- und Konfigurationsebene der VID-Architektur. Sie stellt alle Policy-basierten Einstellungen für die darüberliegenden Schichten bereit -- insbesondere die Konfiguration von Benutzerprofilen, Netzwerkpfaden und Zugriffsrechten via Gruppenrichtlinien (GPO).

Schicht 4 ist die einzige Schicht, die Umgebungswissen (Domainnamen, UNC-Pfade, IP-Adressen von Servern) in die höheren Schichten trägt. Alle anderen Schichten (5, 6, 7) sind frei von dieser Information.

## 10.1 SMB Share für Profile: GPO-Konfiguration

> **VID-ARCHITEKTURPRINZIP** Das SMB Share für Benutzerprofile wird AUSSCHLIESSLICH über Gruppenrichtlinien in Schicht 4 (Active Directory) konfiguriert. Das Golden Image (Schicht 5) enthält KEINEN hardcodierten Profilpfad. Dies ist ein fundamentales VID-Prinzip: Umgebungsspezifische Konfiguration gehört in Schicht 4, nicht ins Image.

Die Trennung zwischen Agent (Schicht 5) und Konfiguration (Schicht 4) ermöglicht es, das exakt gleiche Windows 11 Master Image in verschiedenen Umgebungen (Test, Produktion, DR) einzusetzen -- die Profile-Konfiguration kommt immer aus der jeweiligen GPO-Umgebung.

### **10.1.1 Citrix Profile Manager (CPM) via GPO**

Der Citrix User Profile Manager Agent ist Bestandteil des VDA-Installationspakets und wird in Schicht 5 (Golden Image) automatisch mit installiert. Die Konfiguration des Agents erfolgt vollständig über GPO (Schicht 4):

-   **GPO-Setting:** Profilpfad (UNC): \\\\fileserver\\profiles\\%USERNAME%

-   **GPO-Setting:** Aktivierung des Streaming-Modus, Profilgröße, Ausschlüsse

-   **GPO-Setting:** Log-Level, Synchronisationsintervall

-   **GPO-Setting:** Profilcontainer-Aktivierung (falls FSLogix als Alternative)

### **10.1.2 FSLogix Profile Container als Alternative**

Alternativ zu Citrix Profile Manager kann FSLogix als Profillösung eingesetzt werden. Auch hier gilt das VID-Prinzip: Der FSLogix Agent wird im Image installiert (Schicht 5), alle Einstellungen kommen via GPO (Schicht 4):

  **Einstellung**                    **GPO-Pfad**                            **Wert (Beispiel)**
  ---------------------------------- --------------------------------------- -------------------------------------
  **VHD-Pfad (Profile Container)**   Computer\\FSLogix\\Profile Containers   \\\\fileserver\\fslogix\\%USERNAME%
  **Enabled**                        Computer\\FSLogix\\Profile Containers   1
  **Delete Local Copy On Logoff**    Computer\\FSLogix                       1
  **Included Groups**                Computer\\FSLogix\\Profile Containers   DOMAIN\\Citrix-Desktop-Users
  **Excluded Groups**                Computer\\FSLogix\\Profile Containers   DOMAIN\\Admins
  **VHD Size (MB)**                  Computer\\FSLogix\\Profile Containers   30720 (30 GB)
  **Redirect Windows Search**        Computer\\FSLogix\\Apps                 1

FSLogix kann optional auch über Winget/Chocolatey im App-Manifest (Schicht 7 / apps-manifest.json) vorinstalliert werden, wenn eine appbasierte Bereitstellung gewünscht ist.

## 10.2 Weitere GPO-Konfigurationen (Schicht 4)

Die folgende Tabelle zeigt alle Konfigurationen, die in der VID-Architektur explizit in Schicht 4 (AD / GPO) gehalten werden -- und NICHT im Image:

  **Konfigurationsbereich**                       **Zuständige Schicht**   **Bereitstellung**
  ----------------------------------------------- ------------------------ -----------------------------------
  **SMB Profilpfad (CPM / FSLogix)**              Schicht 4 -- AD/GPO      Gruppenrichtlinie
  **Citrix Profile Manager Einstellungen**        Schicht 4 -- AD/GPO      Citrix ADMX-Templates + GPO
  **FSLogix Konfiguration**                       Schicht 4 -- AD/GPO      FSLogix ADMX-Templates + GPO
  **Laufwerksbuchstaben-Mappings (Home, Dept)**   Schicht 4 -- AD/GPO      GPO Anmeldeskript / Drive Maps
  **Druckerbereitstellung**                       Schicht 4 -- AD/GPO      GPO Printer Deployment
  **Software-Restrictions / AppLocker**           Schicht 4 -- AD/GPO      AppLocker-Policy via GPO
  **IE/Edge Proxy-Einstellungen**                 Schicht 4 -- AD/GPO      GPO Internet Explorer / Edge ADMX
  **Windows Update Deferral**                     Schicht 4 -- AD/GPO      GPO (in VDI via neuem Image)
  **BitLocker / Encryption Policy**               Schicht 4 -- AD/GPO      GPO BitLocker Drive Encryption
  **Citrix Receiver/CSSC Einstellungen**          Schicht 4 -- AD/GPO      Citrix ADMX-Templates + GPO
  **DNS Suffix Search List**                      Schicht 4 -- AD/GPO      GPO TCPIP-Einstellungen
  **NTP-Server**                                  Schicht 4 -- AD/GPO      GPO Windows Time Service
  **Admin-Gruppen für lokale Admins**             Schicht 4 -- AD/GPO      GPO Restricted Groups
  **Firewall Ausnahmen (domänenspezifisch)**      Schicht 4 -- AD/GPO      GPO Windows Firewall
  **Desktop Hintergrund / Branding**              Schicht 4 -- AD/GPO      GPO Desktop / Personalization

## 10.3 Was Schicht 5 (Image) enthält -- was nicht

Die klare Abgrenzung zwischen Image-Inhalt und GPO-Konfiguration ist ein Kernprinzip von VID. Das folgende Entscheidungsschema zeigt, was in welche Schicht gehört:

  **Frage**                                                **Antwort**                                                 **Schicht**
  -------------------------------------------------------- ----------------------------------------------------------- --------------------
  Ist es ein Agent/Service, der auf jedem Desktop läuft?   Ja → im Image installieren                                  Schicht 5 / Packer
  Ist es eine Konfiguration, die umgebungsabhängig ist?    Ja → via GPO konfigurieren                                  Schicht 4 / AD
  Ist es ein UNC-Pfad, IP oder Servername?                 Ja → niemals ins Image, immer GPO                           Schicht 4 / AD
  Ist es ein Treiber oder Guest-Tool?                      Ja → Schicht 6 (hypervisorspezifisch)                       Schicht 6 / Packer
  Ist es eine Business-Anwendung?                          Ja → Schicht 7, via Manifest (Winget/Chocolatey)            Schicht 7 / Apps
  Ist es eine Sicherheits-Policy?                          Ja → GPO (domänenweite Durchsetzung), kein Image-Hardcode   Schicht 4 / AD

## 10.4 AD-Struktur für VID-Deployments

Für ein VID-konformes Active Directory empfiehlt sich die folgende OU-Struktur, die eine klare Trennung von Maschinen-, Benutzer- und Service-Objekten ermöglicht:

  **OU-Pfad**                              **Inhalt**                        **GPO-Verknüpfung**
  ---------------------------------------- --------------------------------- -------------------------------------------
  **OU=VID,DC=domain,DC=local**            Root-OU für VID-Objekte           VID-Basis-Policy
  **OU=Desktops,OU=VID,\...**              MCS-provisionierte W11-Computer   Desktop-Policy (FSLogix, CPM, Firewall)
  **OU=Desktops\\VMware,OU=VID,\...**      VMware-MCS Computer-Objekte       VMware-spezifische Einstellungen
  **OU=Desktops\\XenServer,OU=VID,\...**   XenServer-MCS Computer-Objekte    XenServer-spezifische Einstellungen
  **OU=Users,OU=VID,\...**                 VDI-Benutzer                      Benutzer-Policy (Profil, Drucker, Drives)
  **OU=ServiceAccounts,OU=VID,\...**       MCS-SA, Citrix-SA, FSLogix-SA     Keine interaktive Anmeldung
  **OU=Groups,OU=VID,\...**                Berechtigungsgruppen              \-

> **BEST PRACTICE** Empfehlung: Separate OUs für VMware- und XenServer-Desktops ermöglichen hypervisorspezifische GPO-Einstellungen (z.B. unterschiedliche Profile-Pfade für Test- und Produktionsumgebungen) ohne das Image anzupassen. Dies ist der VID-Ansatz: Umgebungsunterschiede über GPO, nicht über Images.

## 10.5 Voraussetzungen (Vorher) für Schicht 4

Gemäß dem VID-Vorher-Prinzip müssen folgende Voraussetzungen erfüllt sein, bevor Schicht 4 konfiguriert werden kann:

-   Active Directory Domain Services installiert und erreichbar

-   Domain-Controller für die Zielumgebung deployed

-   DNS korrekt konfiguriert (AD-DNS als primärer DNS für alle VMs)

-   ADMX-Templates für Citrix (VDA, CPM, Receiver) in den Central Store importiert

-   ADMX-Templates für FSLogix in den Central Store importiert

-   SMB-Share für Profile erstellt und Berechtigungen gesetzt (Creator Owner: Modify)

-   Service-Accounts für MCS, Citrix und FSLogix angelegt und dokumentiert

-   Gruppenstruktur für VID-Benutzer und VID-Desktops definiert

# 11 Erweitertes VID-Schichtenmodell (v1.1)

Basierend auf dem Architektur-Arbeitsdiagramm wurde das ursprüngliche 7-Schichten-Modell um eine 8. Schicht (Monitoring / DEX) erweitert. Zusätzlich wird die Container-Unterstützung als optionale Erweiterung von Schicht 5 vorgemerkt.

  **\#**   **Schicht**                 **Verantwortung**                   **Phase**   **Beispiel-Technologien**
  -------- --------------------------- ----------------------------------- ----------- ------------------------------------------------
  **1**    x86 Hardware                Server, Netzwerk, Storage           Phase 3+    HPE ProLiant, Dell, Cisco, NetApp
  **2**    Hypervisor                  Virtualisierungsplattform           Phase 2     VMware vSphere, Citrix Hypervisor, Azure Local
  **3**    Hypervisor-Management       Orchestrierung, IaC, Provisioning   Phase 2     vCenter, XenCenter, Terraform
  **4**    Active Directory / IDP      Identität, GPO, Profile-Policy      Annahme     AD, Entra ID, GPO, FSLogix ADMX
  **5**    Windows 11 VM / Container   Gast-OS, Golden Image               Phase 1     W11 Pro/Enterprise, Packer, MCS
  **6**    Treiber / Guest Agents      Hypervisor-Integration              Phase 1     VMware Tools, Citrix VM Tools, XenTools
  **7**    Applikationen               Business-Software                   Phase 1     Office, SAP, Browser, Winget/FSLogix
  **8**    Monitoring / DEX            Experience, Telemetrie, Metriken    Phase 2     Nexthink, Lakeside SysTrack, 1E Tachyon

## 11.1 Schicht 8: Monitoring / Digital Employee Experience

Schicht 8 misst die Qualität der bereitgestellten Desktop-Erfahrung und sammelt Metriken für Kapazitätsplanung, SLA-Monitoring und proaktive Problemerkennung. Sie ist vollständig von den darunter liegenden Schichten entkoppelt -- ein Wechsel des Monitoring-Tools erfordert keine Änderung am Image oder an der Infrastruktur.

-   **DEX:** Digital Employee Experience (DEX): Messung der subjektiven und objektiven User Experience

-   **Citrix DaaS:** Session-Metriken: Latenz, Framerate, Protokoll-Qualität (HDX Score)

-   **Infrastruktur:** OS-Metriken: CPU, RAM, Disk I/O pro VM und pro User

-   **APM:** Application Performance: Startup-Zeit, Crash-Rate, Antwortzeit

-   **Alerting:** Proaktive Alerts: Schwellwerte, Anomalie-Erkennung, automatische Remediation

> **SCHICHTENTRENNUNG MONITORING** Monitoring-Agenten (z.B. Nexthink Collector, Lakeside SysTrack Agent) werden in Schicht 5 (Golden Image) vorinstalliert. Die Agent-Konfiguration (Server-Adresse, Tenant-ID) kommt via GPO aus Schicht 4. Dies folgt demselben Prinzip wie Profile-Agents: Agent im Image, Config in der GPO.

## 11.2 Vorher-Modell: Voraussetzungen je Schicht

Das Vorher-Modell dokumentiert formal, welche Voraussetzungen erfüllt sein müssen, bevor eine Schicht installiert oder konfiguriert werden kann. Dieses Modell wurde aus dem VID-Architektur-Arbeitsdiagramm übernommen.

  **Schicht**                             **Vorher-Voraussetzungen**
  --------------------------------------- ------------------------------------------------------------------------------------------------------------------------------------
  **1 -- x86 Hardware**                   Rackspace · Power & Cooling · Netzwerk (freie Ports) · IP/Gateway/DNS für ILO
  **2 -- Hypervisor**                     Zertifizierte Hardware (Schicht 1) · IP/Gateway/DNS für Hypervisor-Management
  **3 -- Hypervisor-Management**          Hypervisor installiert (Schicht 2) · Netzwerk (VPN via JumpHost / VLAN) · Zertifizierte Virtualisierungsumgebung
  **4 -- Active Directory / IDP**         Infrastruktur-VMs bereit (Schicht 3) · IDP Credentials · SMB-Share für Profile eingerichtet · Service-Accounts angelegt
  **5 -- Windows 11 VM (Golden Image)**   Hypervisor + vCenter (Schicht 2+3) · AD/IDP (Schicht 4) · Maschinen-Katalog · Golden Image Build · Gruppenrichtlinien konfiguriert
  **6 -- Treiber / Guest Agents**         Windows 11 Base Image (Schicht 5) · Hypervisor-ISO auf Datastore/SR verfügbar
  **7 -- Applikationen**                  Betriebssystem inkl. Treiber (Schicht 5+6) · Winget/Chocolatey verfügbar · apps-manifest.json konfiguriert
  **8 -- Monitoring / DEX**               Fertig eingerichtete Desktop-Instanz (Schicht 5-7) · Monitoring-Server deployed · Agent-GPO konfiguriert

# 12 Architekturentscheidung: VDA und Profil-Management in Schicht 7

Eine zentrale Architekturentscheidung im VID-Rahmenwerk legt fest, dass der Remote-Desktop-Broker-Agent (Citrix VDA) und die Profil-Management-Lösung (FSLogix / Citrix Profile Manager) der Schicht 7 (Applikationsschicht) zugeordnet werden -- und NICHT Schicht 5 (Windows 11 OS-Image).

## 12.1 Begründung

Diese Entscheidung folgt direkt aus dem VID-Kernprinzip der Vendor-Unabhängigkeit:

-   **Problem ohne diese Entscheidung:** Wenn der VDA in Schicht 5 (Image) liegt, muss beim Wechsel von Citrix zu Microsoft AVD oder VMware Horizon das gesamte OS-Image neu gebaut werden. Das widerspricht dem VID-Prinzip.

-   **Vorteil durch diese Entscheidung:** Wenn der VDA in Schicht 7 liegt, reicht es, das VDA-Installationsskript im App-Manifest auszutauschen. Das OS-Image (Schicht 5) bleibt unverändert.

> **VID-KERNENTSCHEIDUNG** Der Broker-Agent (VDA / AVD Agent / Horizon Agent) ist eine Technologie-Entscheidung auf Schicht 7 -- genauso wie die Wahl zwischen FSLogix und Citrix Profile Manager. Schicht 5 enthält weder Citrix-, noch Microsoft-, noch VMware-spezifische Komponenten.

## 12.2 Aktualisiertes Schichtenmodell

Die folgende Tabelle zeigt das überarbeitete Schichtenmodell mit der korrekten Zuordnung von VDA und Profil-Management:

  **Schicht**                          **Inhalt**                                                                                                                                                              **Austausch-Szenario**
  ------------------------------------ ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- ----------------------------------------------------------------------------
  **5 -- Windows 11 OS**               Reines W11 Pro/Enterprise · OS-Härtung (TLS, RDP, Firewall) · Windows Updates · KEINE Broker-Agents · KEINE Profil-Tools                                                OS-Version wechseln (W11 → W12) ohne Änderung an Schicht 6 oder 7
  **6 -- Treiber / Guest Agents**      VMware Tools · Citrix VM Tools (XenServer) · Hypervisor-spezifische PV-Treiber                                                                                          VMware → XenServer: nur Schicht-6-Script wechseln, Schicht 5 bleibt gleich
  **7 -- Applikationen (erweitert)**   Remote-Desktop-Broker-Agent (Citrix VDA / AVD Agent / Horizon Agent) · Profil-Management (FSLogix / Citrix Profile Manager / UEM) · Business-Apps · Monitoring-Agents   Citrix → AVD: VDA-Script austauschen. OS-Image (Schicht 5+6) unverändert

## 12.3 Broker-Agent Austauschbarkeit (Layer 7)

Die folgende Tabelle zeigt die unterstützten Broker-Agents und ihre Installationskommandos -- alle austauschbar innerhalb von Schicht 7:

  **Broker**                 **Agent**                     **Installationsweg**                                **VID-Status**
  -------------------------- ----------------------------- --------------------------------------------------- ----------------------
  **Citrix DaaS (Cloud)**    Citrix VDA Workstation        windows-citrix-vda.ps1 (Winget: Citrix.VDA)         Phase 1 -- aktiv
  **Microsoft AVD / W365**   Azure Virtual Desktop Agent   windows-avd-agent.ps1 (winget: Microsoft.RDAgent)   Phase 3 -- geplant
  **VMware Horizon**         Horizon Agent                 windows-horizon-agent.ps1                           Phase 2+ -- optional
  **Nutanix Frame**          Frame Agent                   windows-frame-agent.ps1                             Backlog

> **PHASE 1 SCOPE** Für Phase 1 ist ausschließlich der Citrix VDA implementiert. Die Skriptstruktur ist jedoch so angelegt, dass weitere Agents in windows-\[broker\]-agent.ps1 Dateien ergänzt werden können, ohne Schicht 5 oder 6 zu berühren.

## 12.4 Profil-Management Austauschbarkeit (Layer 7)

Analog zum Broker-Agent ist auch die Profil-Management-Lösung ein Schicht-7-Entscheid:

  **Profil-Lösung**                        **Hersteller**    **Installationsweg (Layer 7)**                    **Konfiguration (Layer 4)**
  ---------------------------------------- ----------------- ------------------------------------------------- --------------------------------
  **Citrix Profile Manager (CPM)**         Citrix            Teil des VDA-Pakets (windows-citrix-vda.ps1)      GPO via Citrix ADMX-Templates
  **FSLogix Profile Container**            Microsoft         winget: Microsoft.FSLogix / windows-fslogix.ps1   GPO via FSLogix ADMX-Templates
  **Liquidware ProfileUnity**              Liquidware        windows-profileunity.ps1                          Management Console + GPO
  **VMware Dynamic Environment Manager**   VMware/Broadcom   windows-dem.ps1                                   GPO / DEM Console

## 12.5 Angepasste Packer Build-Pipeline (Layer-Bewusstsein)

Obwohl technisch alle Schritte in einem einzigen Packer-Build ablaufen (für MCS-Effizienz), sind die Provisioner-Schritte klar nach VID-Schichten kommentiert und können bei Bedarf in separate Builds aufgeteilt werden:

  -------------------------------------------------------------------------------------------------------------------------
  **Packer-Schritt**            **VID-Schicht**   **Script**                     **Austauschbar ohne Image-Rebuild**
  ----------------------------- ----------------- ------------------------------ ------------------------------------------
  1\. OS Baseline               Schicht 5         windows-prepare.ps1            Nein -- Teil des Base Image

  2\. Windows Updates           Schicht 5         windows-update (Provisioner)   Nein -- Teil des Base Image

  3\. Hypervisor-Treiber        Schicht 6         windows-vmtools.ps1 /\         Ja -- Schicht-6-Script wechseln
                                                  windows-xenserver-tools.ps1    

  4\. VDA Installation          Schicht 7         windows-citrix-vda.ps1         Ja -- Script für anderen Broker ersetzen

  5\. Profil-Management Agent   Schicht 7         (CPM via VDA) /\               Ja -- Alternative Profil-Lösung
                                                  windows-fslogix.ps1            

  6\. Business-Apps             Schicht 7         windows-apps-install.ps1       Ja -- apps-manifest.json anpassen

  7\. Optimierungen             Schicht 7         windows-citrix-optimize.ps1    Ja -- broker-spezifisch

  8\. MCS Prep                  Schicht 7         windows-citrix-mcs-prep.ps1    Ja -- broker-spezifisch
  -------------------------------------------------------------------------------------------------------------------------

## 12.6 Golden Image Build vs. Golden Image Customization

Das VID-Arbeitsdiagramm unterscheidet zwischen zwei Build-Phasen. Diese Unterscheidung spiegelt die Schichttrennung exakt wider:

  -------------------------------------------------------------------------------------------------------------------------------------------
  **Build-Phase**                  **VID-Schichten**                 **Packer-Scripts**             **Output**
  -------------------------------- --------------------------------- ------------------------------ -----------------------------------------
  **Golden Image Build**           Schicht 5 (OS) +\                 windows-prepare.ps1\           Hypervisor-spezifisches W11 Base Image\
                                   Schicht 6 (Treiber)               windows-vmtools.ps1\           (kein Broker, kein Profil-Agent)
                                                                     windows-xenserver-tools.ps1\   
                                                                     + Windows Updates              

  **Golden Image Customization**   Schicht 7 (VDA + Profil + Apps)   windows-citrix-vda.ps1\        Vollständiges MCS-fähiges Master Image\
                                                                     windows-apps-install.ps1\      mit Broker + Profil + Apps
                                                                     windows-citrix-optimize.ps1\   
                                                                     windows-citrix-mcs-prep.ps1    
  -------------------------------------------------------------------------------------------------------------------------------------------

> **PHASEN-ROADMAP** In Phase 1 werden beide Build-Phasen in einem einzigen Packer-Lauf ausgeführt (Effizienz, weniger Builds). In Phase 2+ kann \'Golden Image Build\' als Basis-Template gespeichert werden, auf dem verschiedene \'Customization\'-Varianten (Citrix VDA, AVD Agent, etc.) aufbauen -- ohne das Base Image neu zu bauen.

# 13 Schicht 7 (aktualisiert): Vollständige Definition

Nach der Architekturentscheidung aus Kapitel 12 umfasst Schicht 7 drei Unterkategorien, die alle unabhängig voneinander ausgetauscht werden können:

## 13.1 Schicht 7a -- Remote-Desktop Broker Agent

Der Broker-Agent verbindet das Windows 11 Gast-OS (Schicht 5) mit dem Remote-Desktop-Broker-Service (Schicht 3 / Citrix DaaS). Er ist die einzige broker-spezifische Komponente im Image.

-   **Implementiert:** Phase 1: Citrix VDA (windows-citrix-vda.ps1)

-   **MCS-Modus:** Installationsparameter /mastermcsimage: kein Controller-Lookup im Build-Prozess

-   **Austausch-Variablen:** VDA-Version (LTSR / CR), Komponenten (Browser Content Redirection, etc.)

-   **Erweiterung:** Gleiches Skript-Gerüst für AVD Agent, Horizon Agent (Phase 2+)

## 13.2 Schicht 7b -- Profil-Management Agent

Der Profil-Management-Agent stellt sicher, dass Benutzerdaten und -einstellungen über Session-Grenzen hinweg erhalten bleiben. Agent im Image, Konfiguration in Schicht 4 (GPO).

-   **Aktiv:** Phase 1: Citrix Profile Manager (CPM) -- automatisch mit VDA installiert

-   **Alternative:** Alternativ: FSLogix (windows-fslogix.ps1) -- via apps-manifest.json

-   **Konfiguration:** Profil-Pfad, VHD-Größe, Gruppen → IMMER via GPO (Schicht 4), nie im Image

## 13.3 Schicht 7c -- Business-Applikationen und Monitoring

Alle Business-Anwendungen, IT-Tools und Monitoring-Agenten werden über das JSON-Manifest (apps-manifest.json) und windows-apps-install.ps1 bereitgestellt.

-   **Manifest:** apps-manifest.json: Winget + Chocolatey IDs, pro Gruppe und App aktivierbar

-   **Inhalte:** Runtimes, Produktivität, Browser, Security Tools (siehe Kapitel 5)

-   **Monitoring:** Monitoring Agents (Nexthink, SysTrack): in manifest.json als eigene Gruppe

-   **VID-Prinzip:** Hypervisorunabhängig -- identisches Manifest für VMware und XenServer Images

## 13.4 Zusammenfassung: Layer-Ownership

Endgültige, verbindliche Zuordnung der Komponenten zu VID-Schichten:

  **Komponente**                         **VID-Schicht**   **Installationsweg**              **Konfiguration**
  -------------------------------------- ----------------- --------------------------------- ------------------------
  **Windows 11 OS**                      5 -- OS           Packer / autounattend.xml         Statisch im Image
  **OS-Härtung (TLS, RDP, etc.)**        5 -- OS           windows-prepare.ps1               Statisch im Image
  **Windows Updates**                    5 -- OS           windows-update Provisioner        Automatisch
  **VMware Tools**                       6 -- Treiber      windows-vmtools.ps1               Statisch im Image
  **Citrix VM Tools (XenServer)**        6 -- Treiber      windows-xenserver-tools.ps1       Statisch im Image
  **Citrix VDA**                         7a -- Broker      windows-citrix-vda.ps1            GPO + Cloud Connector
  **FSLogix / Citrix Profile Manager**   7b -- Profil      VDA-Paket / windows-fslogix.ps1   GPO (Schicht 4)
  **SMB Profilpfad**                     4 -- AD/GPO       Gruppenrichtlinie                 GPO (niemals im Image)
  **Business Apps**                      7c -- Apps        windows-apps-install.ps1          apps-manifest.json
  **Monitoring Agents**                  7c -- Apps        apps-manifest.json                GPO + Agent-Config
  **VDA Konfiguration (Controller)**     4 -- AD/GPO       Citrix ADMX-GPO                   GPO (niemals im Image)

> **VID ENTSCHEIDUNGSREGEL** Merksatz für alle Implementierungsentscheidungen: \'Ist es ein Treiber? → Schicht 6. Ist es ein Broker- oder Profil-Agent? → Schicht 7. Ist es eine Umgebungs-Konfiguration mit Pfaden, IPs oder Servernamen? → Schicht 4 (GPO). Ist es das Betriebssystem selbst? → Schicht 5.\'
