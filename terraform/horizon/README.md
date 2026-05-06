# terraform/horizon – VMware Horizon Infrastructure (Future Phase)

> **Status: SCAFFOLD / FUTURE PHASE**
> Dieses Modul ist noch nicht implementiert. Es dient als Platzhalter für die
> spätere Automatisierung der Horizon-Infrastruktur.
>
> Aktuell wird davon ausgegangen, dass Horizon Connection Server + Replica bereits
> manuell oder über andere Prozesse installiert wurden.

---

## Übersicht

Dieses Terraform-Modul provisioniert die komplette VMware Horizon Infrastruktur:

| Modul | Inhalt | Status |
|-------|--------|--------|
| `module-1-vsphere` | Connection Server VMs in vSphere anlegen | 📋 Geplant |
| `module-2-install` | Horizon Connection Server Software installieren | 📋 Geplant |
| `module-3-config` | Pod-Konfiguration, Farms, Desktop Pools | 📋 Geplant |

---

## Geplante Architektur

```
vSphere
└── Horizon Connection Server (Primary)     [module-1 + module-2]
└── Horizon Connection Server (Replica)     [module-1 + module-2]
└── (optional) Horizon Replica weiterer Pod

Horizon Admin (REST API / HV PowerCLI)
└── Global Entitlements                     [module-3]
└── Desktop Pools / RDS Farms               [module-3]
└── Instant Clone Image Assignment          [module-3]
```

---

## Voraussetzungen (geplant)

- vSphere vCenter >= 7.0 (Instant Clones erfordern ESXi 7.0+)
- Horizon 8 (2312 oder neuer empfohlen)
- Active Directory mit OU-Struktur für VDI-Computers und Service Accounts
- Netzwerkzugang: Blast/PCoIP (443, 4172, 8443), UAG falls extern
- WinRM auf VM-Templates aktiviert (für Provisioning via Terraform null_resource)

---

## Reihenfolge (zukünftig)

```bash
# Schritt 1: VMs in vSphere anlegen
cd module-1-vsphere
terraform init && terraform apply

# Schritt 2: Horizon Connection Server installieren
cd ../module-2-install
terraform init && terraform apply

# Schritt 3: Horizon-Konfiguration (Pools, Farms etc.)
cd ../module-3-config
terraform init && terraform apply
```

---

## Hinweis zur VID-Integration

Nach Abschluss der Horizon-Infrastruktur:
- Packer-Templates unter `packer/11-horizon/` verwenden
- Horizon Agent wird über `packer/scripts/windows/windows-horizon-agent-install.ps1` installiert
- Pool-Konfiguration in Modul 3 referenziert die Packer-Image-Namen

---

*Dieses Scaffold wurde im Rahmen von VID v2.1 als Future-Phase-Platzhalter angelegt.*
