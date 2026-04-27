#!/usr/bin/env bash
# Build a single PDF from all the chapters in docs/manual/.
#
# Pipeline:
#   1. Concatenate README.md + 01..13 in order, stripping the
#      navigation (prev/next) lines so the printed book reads
#      cleanly.
#   2. Render to HTML via pandoc with embedded styles.
#   3. Print to PDF via puppeteer-core (uses Chrome.app + the
#      module installed at /tmp/node_modules from the screenshot
#      tooling — see script/screenshot.js).
#
# Output: docs/manual/Kitchef-Manual.pdf
#
# Usage: bash script/manual_to_pdf.sh
set -euo pipefail

cd "$(dirname "$0")/.."
MANUAL_DIR="docs/manual"
# Write the HTML INSIDE docs/manual so relative `images/...` paths
# resolve when puppeteer loads it via file://.
OUT_HTML="$MANUAL_DIR/.kitchef-manual.tmp.html"
OUT_PDF="$MANUAL_DIR/Kitchef-Manual.pdf"
TMP_MD="$(mktemp -t kitchef-manual.XXXXXX.md)"
CSS_HEAD="$(mktemp -t kitchef-manual-css.XXXXXX.html)"

trap 'rm -f "$OUT_HTML" "$TMP_MD" "$CSS_HEAD"' EXIT

# ---- 1. Concatenate ---------------------------------------------------
# Strip the prev/next navigation lines (lines containing "Anterior:" or
# "Siguiente:" or "Volver al índice") so the printed book reads as a
# continuous document. Page breaks between chapters come from the
# `h1 { break-before: page }` CSS rule below — no need to inject
# manual <div page-break> elements (which would double-break).
{
  cat "$MANUAL_DIR/README.md"
  for i in 01 02 03 04 05 06 07 08 09 10 11 12 13; do
    file=$(ls "$MANUAL_DIR/$i-"*.md 2>/dev/null | head -1)
    if [ -n "$file" ]; then
      printf "\n\n"
      cat "$file"
    fi
  done
} | grep -vE "Volver al índice|Anterior: \[|Siguiente: \[" > "$TMP_MD"

# ---- 2. Print CSS ----------------------------------------------------
# Inlined into the <head> via --include-in-header. We can't use
# --css=/dev/stdin because pandoc emits a literal <link href="/dev/stdin">
# that puppeteer can't resolve later.
cat > "$CSS_HEAD" <<'CSS'
<style>
@page { size: A4; margin: 18mm 16mm; }
body {
  font-family: -apple-system, "Helvetica Neue", Helvetica, Arial, sans-serif;
  font-size: 11pt;
  line-height: 1.55;
  color: #0E1714;
  max-width: none;
  margin: 0;
}
h1 {
  font-family: "Times New Roman", Georgia, serif;
  font-size: 24pt;
  margin-top: 0;
  border-bottom: 2px solid #0A5A3C;
  padding-bottom: 6pt;
  break-before: page;
}
h1:first-of-type { break-before: auto; }
h2 {
  font-family: "Times New Roman", Georgia, serif;
  font-size: 17pt;
  margin-top: 18pt;
  color: #0A5A3C;
}
h3 { font-size: 13pt; margin-top: 14pt; }
h4 { font-size: 11pt; margin-top: 10pt; }
p, li { font-size: 11pt; }
img {
  display: block;
  width: auto;
  max-width: 170mm;
  max-height: 200mm;
  height: auto;
  margin: 8pt auto;
  border: 1px solid #E5E1D8;
  border-radius: 4pt;
  break-inside: avoid;
}
table {
  border-collapse: collapse;
  margin: 12pt 0;
  width: 100%;
  font-size: 10pt;
  break-inside: avoid;
}
th, td {
  border: 1px solid #E5E1D8;
  padding: 6pt 9pt;
  text-align: left;
  vertical-align: top;
}
th { background: #F8F6F1; font-weight: 600; }
code {
  background: #F8F6F1;
  padding: 1pt 4pt;
  border-radius: 3pt;
  font-family: "SF Mono", Menlo, Consolas, monospace;
  font-size: 9.5pt;
}
pre {
  background: #F8F6F1;
  padding: 10pt 12pt;
  border-radius: 4pt;
  border-left: 3px solid #0A5A3C;
  overflow-x: auto;
  font-size: 9.5pt;
  break-inside: avoid;
}
pre code { background: none; padding: 0; }
blockquote {
  border-left: 3px solid #0A5A3C;
  margin: 10pt 0;
  padding: 4pt 12pt;
  background: #F8F6F1;
  color: #2F3A35;
  font-size: 10.5pt;
}
a { color: #0A5A3C; text-decoration: none; }
hr { border: 0; border-top: 1px solid #E5E1D8; margin: 18pt 0; }
ul, ol { padding-left: 22pt; }
</style>
CSS

# ---- 3. Markdown → HTML ----------------------------------------------
# NOTE: no `--metadata title=...` — README.md already starts with
# `# Manual de operaciones · Kitchef`, so adding a metadata title
# would render it twice.
pandoc "$TMP_MD" \
  --from=markdown+lists_without_preceding_blankline \
  --to=html5 \
  --standalone \
  --resource-path="$MANUAL_DIR" \
  --include-in-header="$CSS_HEAD" > "$OUT_HTML"

# ---- 4. HTML → PDF via puppeteer -------------------------------------
ABS_HTML="$(cd "$(dirname "$OUT_HTML")" && pwd)/$(basename "$OUT_HTML")"
ABS_PDF="$(cd "$(dirname "$OUT_PDF")" && pwd)/$(basename "$OUT_PDF")"
node -e '
const puppeteer = require("/tmp/node_modules/puppeteer-core");
(async () => {
  const browser = await puppeteer.launch({
    executablePath: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    headless: "new",
    args: ["--no-sandbox"],
  });
  const page = await browser.newPage();
  await page.emulateMediaFeatures([{ name: "prefers-color-scheme", value: "light" }]);
  await page.goto("file://" + process.argv[1], { waitUntil: "networkidle0", timeout: 60000 });
  await page.pdf({
    path: process.argv[2],
    format: "A4",
    printBackground: true,
    margin: { top: "18mm", right: "16mm", bottom: "18mm", left: "16mm" },
    displayHeaderFooter: true,
    headerTemplate: "<div></div>",
    footerTemplate: `
      <div style="font-size:8pt; width:100%; padding:0 16mm; color:#6B7670; display:flex; justify-content:space-between;">
        <span>Manual de operaciones &middot; Kitchef</span>
        <span class="pageNumber"></span>
      </div>`,
  });
  await browser.close();
  console.log("OK " + process.argv[2]);
})().catch(e => { console.error(e.message); process.exit(1); });
' "$ABS_HTML" "$ABS_PDF"

echo "Generated: $OUT_PDF ($(du -h "$OUT_PDF" | cut -f1))"
