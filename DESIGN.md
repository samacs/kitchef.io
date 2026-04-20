# Kitchef — Design Guidelines

> **El sistema operativo de tu cocina.** Kitchef is a LatAm-fintech-grade tool for independent home cooks in México. The visual language is warm-technical, Spanish-native, aspirational-professional — think Kueski / Nu / Mercado Pago, not cottage-food marketplace. This document is the single source of truth for color, type, spacing, components, and copy.

Reference files:
- `Kitchef Landing Page.html` — primary landing (split hero + bento + dashboard preview)
- `Kitchef Dashboard.html` — in-product surface (what the cocinera uses daily)

---

## 1. Design Principles

1. **Treat her as a CEO.** The cocinera is a business owner. Interfaces communicate precision, numbers, reliability — not coziness.
2. **Warm-technical.** Serif headlines + mono accents + near-white surfaces. Professional without being cold.
3. **Mexican, not translated-Mexican.** Peso signs, colonia names, `tú` (never `usted`), names like Carmen / Lupita / Elena / Marisol.
4. **Real data over decoration.** Every visual surface shows actual numbers (pedidos, margen, pesos) — never lorem-ipsum or stock imagery.
5. **One strong accent, held back.** Deep green carries everything. No rainbow palettes, no gradient backgrounds, no emoji-as-UI.
6. **Generous whitespace, grounded type.** Body copy caps at `max-w-[620px]`. Section padding at least 72px.

---

## 2. Color System

### 2.1 Tokens

Define as CSS custom properties; components never reference raw hex.

```css
:root {
  /* Ink */
  --ink:         #0E1714;   /* primary text, near-black warm */
  --ink-2:       #2F3A35;   /* secondary text, paragraph */
  --muted:       #6B7670;   /* labels, captions, meta */

  /* Surface */
  --bg:          #F8F6F1;   /* page — bone off-white, NEVER pure white */
  --bg-2:        #EFEBE3;   /* subtle zone: table headers, code blocks, chart grids */
  --surface:     #FFFFFF;   /* cards — pure white is okay ON bone */

  /* Lines */
  --line:        #E4DED1;   /* primary dividers + card borders */
  --line-2:      #D0C9B8;   /* hover / stronger dividers */

  /* Accent */
  --accent:      #0A5A3C;   /* deep green — CTAs, active states, metric deltas */
  --accent-2:    #074830;   /* hover, pressed */
  --accent-soft: #E3EDE6;   /* accent @ 6% — tag backgrounds, chart fills */

  /* Status */
  --pos:         #0A5A3C;   /* positive — same hue as accent by design */
  --warn:        #B04E0E;   /* attention: pending, atrasado */
  --err:         #9B2B1E;   /* destructive: cancelado, falla */
}

.dark {
  --ink:         #F2EFE8;
  --ink-2:       #CFC9BC;
  --muted:       #8C8578;
  --bg:          #0E1714;
  --bg-2:        #152420;
  --surface:     #1A2622;
  --line:        #263531;
  --line-2:      #344540;
  --accent:      #3FAE7D;   /* lifts ~40% in dark for legibility */
  --accent-2:    #6CC399;
  --accent-soft: #12352A;
}
```

### 2.2 Status tokens — light + dark

| Status     | Light bg        | Light fg      | Dark bg       | Dark fg       |
|------------|-----------------|---------------|---------------|---------------|
| Listo      | `--accent-soft` | `--accent`    | `--accent-soft` | `--accent-2` |
| En producción | `#FFF1DD`    | `--warn`      | `#3B2914`     | `#E8B574`     |
| Nuevo      | `#E7F0FB`       | `#1F5BB8`     | `#132A47`     | `#7FAEEB`     |
| Atrasado   | `#FBE8E4`       | `--err`       | `#3A1C16`     | `#E58978`     |

Render as pill: `font-size: 10.5px; padding: 2px 8px; border-radius: 99px;` with a 5px dot prefix.

### 2.3 Don'ts

- ❌ Pure `#FFFFFF` for page background — always bone (`--bg`)
- ❌ Pure `#000000` anywhere
- ❌ Terracotta, cream, mole browns (previous direction — retired)
- ❌ Purple, teal, multi-stop gradients
- ❌ Gradient backgrounds on CTAs — solid green, full-strength
- ❌ More than one semantic color on a single screen

---

## 3. Typography

### 3.1 Font stack

```html
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Instrument+Serif:ital@0;1&family=Inter:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
```

```css
--serif: 'Instrument Serif', Georgia, serif;   /* headlines, metric values */
--sans:  'Inter', -apple-system, system-ui, sans-serif;  /* UI + body */
--mono:  'JetBrains Mono', ui-monospace, monospace;       /* prices, deltas, kickers, timestamps */
```

> **Why this stack:** Instrument Serif is a modern editorial serif with a single weight (400) and a strong italic. The italic is an intentional expressive tool — use it for key brand words. Inter handles UI density. JetBrains Mono signals "data" in dashboards. No Fraunces, no General Sans, no system fonts as primary.

### 3.2 Scale

| Usage                    | CSS                                                                                   | Notes                                        |
|--------------------------|---------------------------------------------------------------------------------------|----------------------------------------------|
| Display (hero H1)        | `font-family:serif; weight:400; font-size:clamp(44px,6.2vw,78px); line-height:1.15; letter-spacing:-.02em; padding-bottom:.15em` | Italic descenders need the padding. |
| Section H2               | `serif; 400; clamp(34px,4.2vw,52px); line-height:1.04; letter-spacing:-.02em`         |                                              |
| Card H3                  | `serif; 400; 28px; line-height:1.1; letter-spacing:-.015em`                           |                                              |
| Metric value (serif)     | `serif; 400; 22–54px; letter-spacing:-.01em`                                          | Pair with mono delta.                         |
| Body / lede              | `sans; 400; 17–18px; line-height:1.55; color:var(--ink-2); max-width:620px`           |                                              |
| UI text                  | `sans; 500; 13–14px; line-height:1.4`                                                 |                                              |
| Label / eyebrow          | `mono; 500; 11.5px; letter-spacing:.18em; text-transform:uppercase; color:var(--accent)` | Prefix with a 20px horizontal rule.        |
| Price / delta / code     | `mono; 500; 11–14px; letter-spacing:.02em`                                            |                                              |
| Micro caption            | `sans; 500; 12px; color:var(--muted)`                                                 |                                              |

### 3.3 Italic as an expressive tool

Wrap exactly **one** word per headline in `<em>` — and style it `font-style: italic; color: var(--accent)`. Pick the word that carries the pivot: "el sistema operativo de tu _cocina_," "tu semana, _visible_," "sin _comisión_." Over-use flattens the effect.

### 3.4 Copy tone

- `tú`, never `usted`
- Plain Mexican Spanish: `pedidos`, `anticipo`, `entrega`, `colonia`, `platillo`, `margen`, `atrasado`
- Aspirational-professional: "Tu cocina merece un sistema, no un cuaderno." Never cute, never folksy.
- Banned: *workflow, optimize, empower, leverage, platform, solution, AI, powered, seamless*. Replace with concrete verbs from her world.

---

## 4. Spacing, Radii, Shadows

### 4.1 Radii

| Element                  | Radius |
|--------------------------|--------|
| Pills / badges / dots    | `99px` |
| Form inputs / small btns | `7px`  |
| Buttons                  | `9px`  |
| Cards (small)            | `10px` |
| Cards (standard)         | `14–16px` |
| Large panels (hero dash, CTA block) | `20–24px` |

**No `2xl` bubble corners.** Nothing rounder than 24px.

### 4.2 Shadows

Light mode uses soft, low shadows. Dark mode replaces shadow with a visible border.

```css
--sh-card:  0 2px 8px rgba(14,23,20,.06);
--sh-lift:  0 8px 24px rgba(14,23,20,.10);
--sh-hero:  0 40px 80px -30px rgba(14,23,20,.22), 0 8px 16px -8px rgba(14,23,20,.08);

.dark --sh-card: 0 0 0 1px var(--line);
.dark --sh-hero: 0 40px 80px -30px rgba(0,0,0,.6), 0 0 0 1px var(--line);
```

### 4.3 Layout

- Container: `max-width: 1240px; padding: 0 28px`
- Section vertical padding: `96px` desktop / `64px` mobile
- Bento card min-height: `280px`
- Card interior: `28px` (standard) / `16px` (compact) / `48px` (showcase block)
- Gap between bento cards: `14px`
- Pedido row padding: `9–10px 14px`

---

## 5. Component Patterns

### 5.1 Button

```css
.btn {
  display: inline-flex; align-items: center; gap: 8px;
  font: 600 14px/1 var(--sans);
  padding: 10px 18px;
  border-radius: 9px;
  border: 1px solid var(--line);
  background: var(--surface); color: var(--ink);
  transition: border-color .15s, background .15s, transform .1s;
}
.btn:hover   { border-color: var(--line-2); }
.btn:active  { transform: translateY(.5px); }
.btn-primary { background: var(--accent); color: #F8F6F1; border-color: var(--accent); }
.btn-primary:hover { background: var(--accent-2); border-color: var(--accent-2); }
.btn-ghost   { background: transparent; border-color: transparent; }
.btn-sm      { padding: 7px 13px; font-size: 13px; }
```

### 5.2 Pill / badge

```css
.pill {
  display: inline-flex; align-items: center; gap: 6px;
  font: 500 12px/1 var(--sans);
  padding: 4px 10px;
  border-radius: 99px;
  border: 1px solid var(--line);
  background: var(--surface); color: var(--ink-2);
}
.pill.accent { background: var(--accent-soft); border-color: transparent; color: var(--accent); }
```

### 5.3 Card

```css
.card {
  background: var(--surface);
  border: 1px solid var(--line);
  border-radius: 16px;
  padding: 28px;
  display: flex; flex-direction: column; gap: 14px;
}
```

Standard anatomy:
1. Icon badge (34×34, `--accent-soft` background) — optional
2. Mono kicker (label)
3. Serif H3 with italic pivot-word
4. Sans paragraph at 14.5px / 1.55
5. Data visual or list (actual interface, not lorem)

### 5.4 Pedido row (used across landing + dashboard)

```html
<div class="row">
  <div>
    <div class="who">Doña Carmen</div>
    <div class="what">Tamales verdes · 2kg</div>
  </div>
  <span class="st ok"><i></i> Listo</span>
  <span class="amt">$650</span>
</div>
```

```css
.row {
  display: grid;
  grid-template-columns: minmax(0,1fr) auto auto;
  gap: 10px;
  align-items: center;
  padding: 10px 14px;
  border-bottom: 1px solid var(--line);
}
.row .who  { font-weight: 600; color: var(--ink); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.row .what { font-size: 11.5px; color: var(--muted); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.row .amt  { font-family: var(--mono); font-size: 12.5px; font-weight: 500; }
.st        { font: 500 10.5px/1 var(--sans); padding: 2px 8px; border-radius: 99px; display: inline-flex; align-items: center; gap: 5px; }
.st i      { width: 5px; height: 5px; border-radius: 99px; background: currentColor; }
.st.ok     { background: var(--accent-soft); color: var(--accent); }
.st.wait   { background: #FFF1DD; color: var(--warn); }
.st.new    { background: #E7F0FB; color: #1F5BB8; }
```

### 5.5 Stat card (metric)

Serif value + mono delta. Always both.

```html
<div class="dash-stat">
  <div class="lbl">Ventas</div>
  <div class="val">$13,400 <span class="delta">↑ 18%</span></div>
</div>
```

```css
.lbl   { font: 500 11px/1 var(--sans); color: var(--muted); letter-spacing: .04em; text-transform: uppercase; }
.val   { font: 400 24px/1 var(--serif); color: var(--ink); letter-spacing: -.01em; display:flex; align-items:baseline; gap:6px; }
.delta { font: 500 11px/1 var(--mono); color: var(--pos); }
```

### 5.6 Section header

```html
<div class="sec-intro">
  <div class="kicker">Una herramienta, cuatro oficios</div>
  <h2>Lo que antes te tomaba <em>horas</em>, ahora son minutos.</h2>
  <p>…lede…</p>
</div>
```

```css
.kicker { display:inline-flex; align-items:center; gap:8px; font-family:var(--mono); font-size:11.5px; letter-spacing:.18em; text-transform:uppercase; color:var(--accent); margin-bottom:16px; }
.kicker::before { content:""; width:20px; height:1px; background:var(--accent); }
```

### 5.7 Pricing card

Three tiers: **Libreta** (free) / **Cocina** (popular) / **Taller**. Popular variant inverts to ink background — never accent, never gradient.

### 5.8 FAQ accordion

Native `<details>`. Plus icon rotates 45° on open and turns accent. No chevrons.

---

## 6. Dashboard patterns

The dashboard uses the same tokens with tighter spacing.

### 6.1 Shell

- **Sidebar** 240px wide, `--bg-2` background, serif logo, sans nav items, mono label on section dividers.
- **Top bar** 56px, sticky, border-bottom, contains breadcrumb + search + date range + theme toggle.
- **Content** max-width none; pad 28px; bento grids where possible.

### 6.2 Data density

- Default row height 44px; compact mode 36px. Expose as Tweak.
- Tables: `--bg-2` header, mono monetary columns, sans text columns.
- Charts: `--accent` stroke, `--accent-soft` fill, `--line` gridlines at 33% increments.

### 6.3 Empty states

Serif headline ("Nada por aquí todavía"), sans sub, single primary CTA. Never illustrations of boxes.

### 6.4 Status everywhere

Every pedido, pago, producción item shows a status pill (§2.2). Never color-only — always label + dot.

---

## 7. Dark mode

Three-state toggle: **auto → light → dark**. Persists in `localStorage('kitchef_theme')`. System preference listened for when `auto`.

```js
const stored = localStorage.getItem('kitchef_theme') || 'auto';
function apply(mode){
  const sys = matchMedia('(prefers-color-scheme: dark)').matches;
  const dark = mode === 'dark' || (mode === 'auto' && sys);
  document.documentElement.classList.toggle('dark', dark);
}
```

Inline in `<head>` before paint to avoid FOUC.

---

## 8. Responsive

| Breakpoint | Behavior                                                                      |
|-----------:|-------------------------------------------------------------------------------|
| `≥1000px`  | Two-column hero, 2×2 bento, 3-column pricing, side-by-side showcase           |
| `<1000px`  | H1 caps at 16ch; hero stacks (photo + dash max-width 620px); bento collapses to 1 col |
| `<680px`   | Nav links hide → hamburger; dashboard stats stack; rails stack                |
| `<560px`   | Dashboard sidebar → bottom tab bar                                            |

---

## 9. Motion

- Transition duration: `150ms` for UI state (hover/focus), `250ms` for accordion/toggle, `400ms` for theme swap
- Easing: `ease` default, `ease-out` on entrances, no spring bounces
- Buttons: no translate on hover (retired); `:active` gets `translateY(.5px)`
- Charts: no entrance animation — numbers should feel factual, not marketed
- Forbidden: parallax, auto-playing video, spring-scaling cards, confetti

---

## 10. Accessibility

- Body contrast ≥ 4.5:1 both modes (verified: `--ink-2` on `--bg` ≈ 10.2:1, on dark ≈ 9.8:1)
- Focus ring: `outline: 2px solid var(--accent); outline-offset: 2px`
- Status: never color-only — always label + dot
- Theme toggle: `aria-label="Cambiar modo"` with live-region announcement on change
- FAQ: native `<details>` for progressive enhancement
- Charts: `<svg role="img" aria-labelledby="…">` with a textual summary

---

## 11. Content rules (copy reviews)

- Prices: `$25`, `$249 MXN/mes`. Never `MX$`, never `USD`, never unitless `249`.
- Names: Carmen, Lupita, Elena, Marisol, Sofía, Doña + surname initial. Never "María García", never anglicized.
- Colonias: Condesa, Del Valle, Chapalita, San Pedro, Roma Sur, Narvarte, Escandón.
- Realistic dish prices: tamal `$25–35`, pastel completo `$650–850`, meal-prep semanal `$1,500–2,500`.
- Realistic volumes: 20–120 pedidos/mes, margen 38–72%, ventas semana `$4,000–24,000`.
- Time: 24h clock in timestamps (`14:30`), 12h in conversational copy ("a las 2 de la tarde").
- Dates: `Lun 13 abr` / `13 abr 2026`. Never `04/13`.

---

## 12. Token cheat sheet

```
bg          var(--bg)         page
bg-2        var(--bg-2)       zones
surface     var(--surface)    cards
ink         var(--ink)        primary text
ink-2       var(--ink-2)      body
muted       var(--muted)      labels
line        var(--line)       divider
accent      var(--accent)     CTA + metric delta
accent-soft var(--accent-soft) tag bg + chart fill
pos / warn / err              status
```

---

## 13. File structure

```
/
├── DESIGN.md                        ← this file
├── Kitchef Landing Page.html        ← marketing
├── Kitchef Dashboard.html           ← product
└── components/
    └── ios-frame.jsx                ← (reference only — landing is responsive web)
```

---

*Last revised April 2026. Supersedes all previous versions (terracotta/Fraunces/General Sans). Current direction: **deep green on bone, Instrument Serif + Inter + JetBrains Mono, LatAm fintech grade.***
