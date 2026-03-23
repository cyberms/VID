<#
.SYNOPSIS
    Initialises the raw D: data disk added to the master image for Citrix MCS builds.

.DESCRIPTION
    This script runs ONLY when vid_broker = "citrix-mcs".
    The Packer vsphere-iso source block adds a second disk (Disk 1) to the VM
    via a conditional dynamic storage block in windows.pkr.hcl.

    This script:
      1. Finds the raw disk (no partition table yet)
      2. Initialises it as GPT
      3. Creates a single partition using all available space
      4. Formats it NTFS, label "Data"
      5. Assigns drive letter D:

    After this step the disk is available as D:\ for the rest of the build.
    windows-citrix-mcs-prep.ps1 (Step 12, step [9]) will configure the pagefile
    preference to D:\pagefile.sys.

    MCS ARCHITECTURE NOTE:
      The master image has two disks: C: (OS) and D: (Data / Pagefile).
      When MCS provisions a new VM from this master:
        - C: is created as a copy / differencing disk of the master C: snapshot
        - D: is created as a copy / differencing disk of the master D: snapshot
        - MCS IODriver adds a THIRD disk (write-cache) which gets the next
          available drive letter (E: or similar) — NOT D:.
      The pagefile therefore runs on the persistent D: data disk, not the
      write-cache disk, and not the OS disk.

.NOTES
    VID Layer  : Layer 5 → 7 (broker-specific, citrix-mcs only)
    Called by  : windows.pkr.hcl Step 2c (dynamic provisioner, for_each = citrix-mcs)
    Requires   : Windows PowerShell 5.1+, elevated context
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Message)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Output "[$ts] $Message"
}

Write-Log "=== windows-init-data-disk.ps1 – D: Disk Initialisation (citrix-mcs) ==="

# ── Step 1: Find the raw (uninitialised) disk ────────────────────────────────

Write-Log "Scanning for raw disks..."
$rawDisks = Get-Disk | Where-Object { $_.PartitionStyle -eq "RAW" }

if ($rawDisks.Count -eq 0) {
    Write-Log "WARNING: No raw disk found. D: may already be initialised or disk was not added."
    Write-Log "Checking if D: already exists..."
    if (Test-Path "D:\") {
        Write-Log "D: already exists – skipping initialisation."
        exit 0
    } else {
        Write-Log "ERROR: No raw disk and D: does not exist. Check Packer storage configuration."
        exit 1
    }
}

if ($rawDisks.Count -gt 1) {
    Write-Log "WARNING: $($rawDisks.Count) raw disks found. Using the first one (Disk $($rawDisks[0].Number))."
}

$disk = $rawDisks | Sort-Object Number | Select-Object -First 1
Write-Log "Found raw disk: Disk $($disk.Number) – $([Math]::Round($disk.Size / 1GB, 1)) GB"

# ── Step 2: Initialise as GPT ────────────────────────────────────────────────

Write-Log "Initialising disk $($disk.Number) as GPT..."
Initialize-Disk -Number $disk.Number -PartitionStyle GPT -Confirm:$false
Write-Log "Disk $($disk.Number) initialised (GPT)."

# ── Step 3: Create partition ─────────────────────────────────────────────────

Write-Log "Creating partition on disk $($disk.Number)..."
$partition = New-Partition -DiskNumber $disk.Number -UseMaximumSize -DriveLetter D
Write-Log "Partition created: $($partition.DriveLetter): (offset $($partition.Offset), size $([Math]::Round($partition.Size / 1GB, 2)) GB)"

# ── Step 4: Format NTFS ──────────────────────────────────────────────────────

Write-Log "Formatting D: as NTFS (label: Data)..."
$volume = Format-Volume -DriveLetter D -FileSystem NTFS -NewFileSystemLabel "Data" -Confirm:$false -Force
Write-Log "Format complete: $($volume.FileSystemLabel) ($($volume.FileSystem)), $([Math]::Round($volume.SizeRemaining / 1GB, 2)) GB free"

# ── Step 5: Verify ───────────────────────────────────────────────────────────

Write-Log "Verifying D: is accessible..."
if (Test-Path "D:\") {
    Write-Log "D:\ is accessible. Disk initialisation complete."
} else {
    Write-Log "ERROR: D:\ is not accessible after initialisation."
    exit 1
}

Write-Log "=== D: Disk Initialisation Complete ==="
Write-Log "  Drive letter : D:"
Write-Log "  Label        : Data"
Write-Log "  File system  : NTFS"
Write-Log "  Size         : $([Math]::Round($disk.Size / 1GB, 1)) GB"
Write-Log ""
Write-Log "  Next step: windows-citrix-mcs-prep.ps1 will configure pagefile to D:\pagefile.sys"
