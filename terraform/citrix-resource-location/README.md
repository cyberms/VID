# VID – Phase 1c: Citrix Resource Location Provisioning

> **Status: SCAFFOLD – nicht produktiv**
>
> Für den normalen VID-Betrieb wird vorausgesetzt, dass **Cloud Connectors bereits
> installiert und mit Citrix Cloud verbunden** sind.
>
> Dieses Modul dient dem vollständigen Neuaufbau einer Resource Location (z.B.
> bei DR, neuem Standort oder vollständig automatisiertem Greenfield-Deployment).

## Überblick

Dieses Modul automatisiert das Deployment einer Citrix DaaS Resource Location auf vSphere 8
in drei sequenziellen Schritten (Module müssen nacheinander ausgeführt werden):

```
module-1-vsphere/     → VMs in vSphere erstellen (CC-VMs + Admin-VM)
        ↓
module-2-install/     → Cloud Connector Software installieren + in Citrix Cloud registrieren
        ↓
module-3-hypervisor/  → Hypervisor Connection + Resource Pool in Citrix Cloud anlegen
```

Nach Abschluss von Module 3 ist die Resource Location fertig und `terraform/citrix/`
(Machine Catalog + Delivery Group) kann ausgeführt werden.

## Voraussetzungen

- vSphere 8 Cluster mit ausreichend Ressourcen
- Windows Server 2022 Template/ISO für CC-VMs
- Active Directory Domain + OU für CC-Computerkonten
- Citrix Cloud Account mit Admin-Rechten (customer_id, client_id, client_secret)
- Netzwerkzugriff CC → Citrix Cloud (HTTPS 443)
- Citrix Cloud Connector Installer: `cwcconnector.exe`
- Citrix Remote PowerShell SDK: `CitrixPoshSdk.exe`
  (beide auf SMB-Share oder HTTP-Storage ablegen)

## Modul-Reihenfolge

```bash
# Modul 1: vSphere VMs erstellen
cd module-1-vsphere
cp terraform.tfvars.example terraform.tfvars
terraform init && terraform plan && terraform apply

# Modul 2: Cloud Connector installieren + registrieren (WinRM erforderlich!)
cd ../module-2-install
cp terraform.tfvars.example terraform.tfvars
terraform init && terraform plan && terraform apply

# Modul 3: Hypervisor Connection + Resource Pool
cd ../module-3-hypervisor
cp terraform.tfvars.example terraform.tfvars
terraform init && terraform plan && terraform apply

# Weiter mit Machine Catalog:
cd ../../citrix
terraform init && terraform apply
```

## WinRM-Voraussetzung (Modul 2)

Modul 2 kommuniziert via WinRM mit den CC-VMs für die Installation.
WinRM muss auf den CC-VMs aktiviert sein (via GPO oder Autounattend beim OS-Deploy):

```powershell
# Auf den CC-VMs (einmalig, oder via GPO):
Enable-PSRemoting -Force
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force
```

Alternativ: WinRM via Autounattend.xml im vSphere Template aktivieren.

## Referenz

- [Citrix TechZone: Terraform vSphere Resource Location](https://community.citrix.com/tech-zone/build/deployment-guides/terraform-cvad-vsphere8)
- [Citrix Terraform Provider Docs](https://github.com/citrix/terraform-provider-citrix/tree/main/docs/resources)
- Citrix Automation Handbook 2601 – Part 2 (Automation of DaaS Components)
