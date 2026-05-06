# terraform/avd – Azure Virtual Desktop Infrastructure (Future Phase)

> **Status: SCAFFOLD / FUTURE PHASE**
> Dieses Modul ist noch nicht implementiert. Es dient als Platzhalter für die
> spätere Automatisierung der AVD-Infrastruktur via Terraform.
>
> Für sofortige AVD-Operationen stehen die PowerShell Scripted Actions unter
> `avd/scripted-actions/` zur Verfügung.

---

## Übersicht

Dieses Terraform-Modul provisioniert die komplette Azure Virtual Desktop Infrastruktur:

| Modul | Inhalt | Status |
|-------|--------|--------|
| `module-1-azure-infra` | Resource Groups, VNet, Subnet, RBAC | 📋 Geplant |
| `module-2-hostpool` | Host Pool, Workspace, Application Groups | 📋 Geplant |
| `module-3-sessionhosts` | Session Hosts (VMs + AVD Agent) | 📋 Geplant |

---

## Geplante Architektur

```
Azure Subscription
└── Resource Group: rg-vid-avd-<env>
    ├── VNet: vnet-vid-avd                     [module-1]
    │   └── Subnet: snet-avd-sessionhosts
    ├── Host Pool: hp-vid-<pooltype>           [module-2]
    │   ├── Workspace: ws-vid
    │   ├── Desktop Application Group (DAG)
    │   └── RemoteApp Application Group (RAG) [optional]
    └── Session Host VMs                       [module-3]
        └── AVD Agent + Registration Token
```

---

## Voraussetzungen (geplant)

- Azure Subscription mit Contributor-Rechten
- Azure Active Directory / Entra ID
- Hybrid Join oder Azure AD Join (je nach Identity-Modell)
- Packer-gebautes AVD-Image in Azure Compute Gallery oder als verwaltetes Image
- Service Principal für Terraform (`ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`)

---

## Reihenfolge (zukünftig)

```bash
# Schritt 1: Azure-Infrastruktur (VNet, RGs, RBAC)
cd module-1-azure-infra
terraform init && terraform apply

# Schritt 2: Host Pool + Workspace + App Groups
cd ../module-2-hostpool
terraform init && terraform apply

# Schritt 3: Session Hosts deployen
cd ../module-3-sessionhosts
terraform init && terraform apply
```

---

## Hinweis zur VID-Integration

- Packer-Templates unter `packer/11-avd/` bauen das Basisimage
- AVD Agent wird automatisch via Custom Script Extension installiert
- Scripted Actions für Day-2-Operationen: `avd/scripted-actions/`
- Azure-Authentifizierung via Service Principal (Terraform) oder Managed Identity

---

## Alternativer Ansatz: Bicep / ARM

Für AVD-Deployments ist auch Azure Bicep/ARM eine valide Alternative zu Terraform.
Bei Bedarf kann hier ein Bicep-Modul ergänzt werden.

---

*Dieses Scaffold wurde im Rahmen von VID v2.1 als Future-Phase-Platzhalter angelegt.*
