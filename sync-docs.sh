#!/bin/bash
##########################################################################
# sync-docs.sh
# Konvertiert das Markdown-Architekturkonzept in DOCX (und optional PDF).
#
# Markdown ist die Single Source of Truth.
# DOCX wird aus dem Markdown generiert – niemals umgekehrt editieren!
#
# Voraussetzung: pandoc installiert (https://pandoc.org)
#
# Verwendung:
#   ./sync-docs.sh           # MD → DOCX
#   ./sync-docs.sh --pdf     # MD → DOCX + PDF
#   ./sync-docs.sh --check   # Prüfen ob MD und DOCX noch synchron sind
##########################################################################

set -e

MD_FILE="Vendor-Independence-Day-Architekturkonzept-v1.0.md"
DOCX_FILE="Vendor-Independence-Day-Architekturkonzept-v1.0.docx"
PDF_FILE="Vendor-Independence-Day-Architekturkonzept-v1.0.pdf"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MD_PATH="$SCRIPT_DIR/$MD_FILE"
DOCX_PATH="$SCRIPT_DIR/$DOCX_FILE"
PDF_PATH="$SCRIPT_DIR/$PDF_FILE"

# Optionales pandoc Reference-DOCX für Corporate Styling
# Erstellen mit: pandoc --print-default-data-file reference.docx > reference.docx
REFERENCE_DOCX="$SCRIPT_DIR/docs/reference.docx"

# ─────────────────────────────────────────────────────────────────────────────

if ! command -v pandoc &>/dev/null; then
    echo "FEHLER: pandoc nicht gefunden."
    echo "       Installation: https://pandoc.org/installing.html"
    echo "       macOS: brew install pandoc"
    echo "       Ubuntu: apt install pandoc"
    exit 1
fi

# ── MD → DOCX ────────────────────────────────────────────────────────────────
convert_to_docx() {
    echo "Konvertiere: $MD_FILE → $DOCX_FILE"

    local pandoc_args=(
        "$MD_PATH"
        -o "$DOCX_PATH"
        --from markdown
        --to docx
        -V lang=de
        --toc
        --toc-depth=3
        --highlight-style=tango
    )

    # Reference-DOCX für Styling verwenden (falls vorhanden)
    if [ -f "$REFERENCE_DOCX" ]; then
        pandoc_args+=(--reference-doc="$REFERENCE_DOCX")
        echo "  Verwende Reference-DOCX: $REFERENCE_DOCX"
    fi

    pandoc "${pandoc_args[@]}"
    echo "  ✓ DOCX erstellt: $DOCX_FILE"
}

# ── MD → PDF ─────────────────────────────────────────────────────────────────
convert_to_pdf() {
    echo "Konvertiere: $MD_FILE → $PDF_FILE"

    pandoc "$MD_PATH" \
        -o "$PDF_PATH" \
        --from markdown \
        --to pdf \
        -V lang=de \
        -V geometry:margin=2.5cm \
        -V fontsize=11pt \
        --toc \
        --toc-depth=3 \
        --highlight-style=tango \
        2>/dev/null || {
            echo "  HINWEIS: PDF-Export benötigt LaTeX (texlive) oder WeasyPrint."
            echo "           macOS: brew install --cask mactex"
            echo "           Ubuntu: apt install texlive-xetex"
            return 1
        }
    echo "  ✓ PDF erstellt: $PDF_FILE"
}

# ── Sync-Prüfung ─────────────────────────────────────────────────────────────
check_sync() {
    echo "Prüfe Synchronisation: MD vs DOCX"

    if [ ! -f "$MD_PATH" ]; then
        echo "  FEHLER: MD-Datei nicht gefunden: $MD_FILE"
        exit 1
    fi

    if [ ! -f "$DOCX_PATH" ]; then
        echo "  WARNUNG: DOCX nicht gefunden – bitte sync-docs.sh ausführen."
        exit 1
    fi

    local md_time docx_time
    md_time=$(stat -c %Y "$MD_PATH" 2>/dev/null || stat -f %m "$MD_PATH")
    docx_time=$(stat -c %Y "$DOCX_PATH" 2>/dev/null || stat -f %m "$DOCX_PATH")

    if [ "$md_time" -gt "$docx_time" ]; then
        echo "  WARNUNG: MD ist neuer als DOCX – bitte sync-docs.sh ausführen!"
        echo "  MD:   $(date -r "$MD_PATH" 2>/dev/null || date -d @$md_time)"
        echo "  DOCX: $(date -r "$DOCX_PATH" 2>/dev/null || date -d @$docx_time)"
        exit 1
    else
        echo "  ✓ DOCX ist aktuell (MD-Timestamp ≤ DOCX-Timestamp)"
    fi
}

# ── Dispatch ─────────────────────────────────────────────────────────────────
case "${1:-}" in
    "--pdf")
        convert_to_docx
        convert_to_pdf
        ;;
    "--check")
        check_sync
        ;;
    "")
        convert_to_docx
        ;;
    *)
        echo "Verwendung: ./sync-docs.sh [--pdf|--check]"
        echo "  (kein Argument) : MD → DOCX"
        echo "  --pdf           : MD → DOCX + PDF"
        echo "  --check         : Prüft ob DOCX noch aktuell ist"
        exit 1
        ;;
esac

echo ""
echo "Fertig. Editiere immer nur die Markdown-Datei:"
echo "  $MD_FILE"
