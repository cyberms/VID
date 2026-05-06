# ─────────────────────────────────────────────────────────────────────────────
# VID – Horizon, Modul 2: Horizon Connection Server Installation via WinRM
# Status: SCAFFOLD / FUTURE PHASE – noch nicht implementiert
# ─────────────────────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0"
    }
  }
}
