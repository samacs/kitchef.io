# Kitchef — Design Guidelines

> **La cocina de tu negocio.** A design system rooted in the Mexican home kitchen — warm, grounded, phone-first. This document translates the visual language of the landing page into a Tailwind CSS implementation spec.

---

## 1. Design Principles

1. **Mexican, not translated-Mexican.** Peso signs, colonia names, and second-person familiar (`tú`). No SaaS tropes.
2. **Warm > sterile.** Masa off-whites, terracotta earth, no pure white, no pure black.
3. **Phone-first.** Every component must read at 360px wide before anything else.
4. **Confident but humble.** Serif headlines carry pride; sans body stays grounded.
5. **Generous whitespace, short line-length.** Body copy caps around `max-w-prose`.

---

## 2. Color System

### 2.1 Semantic Tokens

Use **semantic tokens** — never reach for raw hex in components. Define them in `tailwind.config.js` via CSS custom properties so they can flip between light/dark automatically.

```js
// tailwind.config.js
module.exports = {
  darkMode: 'class', // toggle via `dark` class on <html>
  theme: {
    extend: {
      colors: {
        // Brand
        primary:       'rgb(var(--color-primary) / <alpha-value>)',
        'primary-dark':'rgb(var(--color-primary-dark) / <alpha-value>)',
        accent:        'rgb(var(--color-accent) / <alpha-value>)',

        // Surfaces
        bg:        'rgb(var(--color-bg) / <alpha-value>)',
        surface:   'rgb(var(--color-surface) / <alpha-value>)',        // cards
        'surface-alt':'rgb(var(--color-surface-alt) / <alpha-value>)', // cream section bg
        'surface-input':'rgb(var(--color-surface-input) / <alpha-value>)',
        'accent-tint':'rgb(var(--color-accent-tint) / <alpha-value>)', // primary @ 6%
        chaos:     'rgb(var(--color-chaos) / <alpha-value>)',          // antes/después bg

        // Text
        heading:  'rgb(var(--color-heading) / <alpha-value>)',
        body:     'rgb(var(--color-body) / <alpha-value>)',
        muted:    'rgb(var(--color-muted) / <alpha-value>)',

        // Borders / separators
        border:    'rgb(var(--color-border) / <alpha-value>)',
        separator: 'rgb(var(--color-separator) / <alpha-value>)',
      },
    },
  },
};
```

### 2.2 CSS Variables — Light

```css
/* app.css */
:root {
  /* Terracotta (default) */
  --color-primary:        196  101  74;   /* #C4654A */
  --color-primary-dark:   168   80  58;   /* #A8503A */
  --color-accent:          91  127  94;   /* #5B7F5E nopal */

  /* Surfaces — warm, domestic, NEVER pure white */
  --color-bg:             250  246  240;  /* masa */
  --color-surface:        255  255  255;
  --color-surface-alt:    245  240  232;  /* cream */
  --color-surface-input:  250  250  250;
  --color-accent-tint:    238  243  238;
  --color-chaos:          240  235  227;

  /* Text */
  --color-heading:         61   43   31;  /* mole */
  --color-body:            92   64   51;
  --color-muted:          138  126  118;

  /* Lines */
  --color-border:         232  226  218;
  --color-separator:      238  238  238;
}

/* Nopal palette variant — apply via `data-palette="nopal"` on <html> */
[data-palette="nopal"] {
  --color-primary:         91  127  94;
  --color-primary-dark:    71  99   73;
  --color-accent:         196  101  74;
  --color-surface-alt:    238  243  238;
  --color-accent-tint:    253  245  242;
}
```

### 2.3 CSS Variables — Dark

```css
.dark {
  --color-bg:              26   20   18;  /* warm near-black, NOT pure #000 */
  --color-surface:         42   34   32;
  --color-surface-alt:     35   29   26;
  --color-surface-input:   35   29   26;
  --color-accent-tint:     30   42   31;
  --color-chaos:           35   29   26;

  --color-heading:        245  240  232;  /* warm off-white */
  --color-body:           196  186  176;
  --color-muted:          138  126  118;

  --color-border:          61   53   46;
  --color-separator:       61   53   46;

  /* Primary stays the same — terracotta reads beautifully on both modes */
}

.dark[data-palette="nopal"] {
  --color-surface-alt:     26   35   28;
  --color-accent-tint:     42   31   28;
}
```

### 2.4 Status Badges (Pedidos)

Status colors need dark-mode variants — avoid pastel backgrounds that glow.

| Status     | Light bg  | Light text | Dark bg   | Dark text |
| ---------- | --------- | ---------- | --------- | --------- |
| Pagado     | `#E8F5E9` | `#2E7D32`  | `#1B3A1B` | `#2E7D32` |
| Pendiente  | `#FFF3E0` | `#E65100`  | `#3A2010` | `#E65100` |
| Confirmado | `#E3F2FD` | `#1565C0`  | `#102540` | `#1565C0` |

Define as utility classes:

```css
@layer utilities {
  .badge-pagado     { @apply bg-[#E8F5E9] text-[#2E7D32] dark:bg-[#1B3A1B]; }
  .badge-pendiente  { @apply bg-[#FFF3E0] text-[#E65100] dark:bg-[#3A2010]; }
  .badge-confirmado { @apply bg-[#E3F2FD] text-[#1565C0] dark:bg-[#102540]; }
}
```

### 2.5 Don'ts

- ❌ Pure `#FFFFFF` or `#000000` anywhere
- ❌ Purple, gradients with multiple saturated stops, "3D blob" colors
- ❌ High-saturation accent colors beyond primary
- ❌ `gray-*` utility scale — we ship semantic tokens only

---

## 3. Typography

### 3.1 Font Stack

```html
<link rel="preconnect" href="https://fonts.googleapis.com" />
<link
  href="https://fonts.googleapis.com/css2?family=Fraunces:opsz,wght@9..144,400;9..144,600;9..144,700;9..144,800&family=General+Sans:wght@400;500;600;700&display=swap"
  rel="stylesheet"
/>
```

```js
// tailwind.config.js
fontFamily: {
  serif: ['Fraunces', 'Georgia', 'serif'],
  sans:  ['"General Sans"', '-apple-system', 'system-ui', 'sans-serif'],
},
```

### 3.2 Type Scale

Headlines always `font-serif`. UI and body always `font-sans`.

| Usage           | Class                                                                                 | Notes                |
| --------------- | ------------------------------------------------------------------------------------- | -------------------- |
| Hero H1         | `font-serif font-bold text-4xl md:text-6xl leading-[1.1] tracking-tight text-heading` | `text-wrap: pretty;` |
| Section H2      | `font-serif font-bold text-3xl md:text-[42px] tracking-tight text-heading`            | center-aligned       |
| Feature H3      | `font-serif font-bold text-2xl md:text-3xl leading-tight text-heading`                |                      |
| Lead paragraph  | `text-base md:text-xl leading-relaxed text-body`                                      | `max-w-prose`        |
| Body            | `text-base leading-relaxed text-body`                                                 |                      |
| Label / eyebrow | `text-xs font-semibold uppercase tracking-[0.1em] text-muted`                         |                      |
| Micro / caption | `text-xs text-muted`                                                                  |                      |

Always pair serif headings with `tracking-tight` (`-0.02em`). Body copy uses default tracking.

### 3.3 Copy Tone

- Second-person familiar: `tú`, never `usted`
- Plain Mexican Spanish: `pedidos`, `anticipo`, `entrega`, `colonia`, `platillo`, `margen`
- No translated-from-English phrasing. If it sounds like Shopify-in-Spanish, rewrite.
- The word `cocina` should appear more often than `negocio`.

---

## 4. Spacing, Radii, Shadows

### 4.1 Radii

Radii are **token-driven** because they're a Tweak. Default is 14px.

```js
borderRadius: {
  card:   'var(--radius-card, 0.875rem)',   // 14px
  button: 'var(--radius-card, 0.875rem)',
  panel:  'calc(var(--radius-card, 0.875rem) + 0.5rem)',
  inner:  'calc(var(--radius-card, 0.875rem) - 0.25rem)',
  pill:   '9999px',
}
```

Usage:
- Cards: `rounded-card`
- Outer frames (antes/después, pricing): `rounded-panel`
- Chips, peso pills, badges: `rounded-pill`

### 4.2 Shadows

Keep shadows soft and low. Dark mode doubles opacity.

```js
boxShadow: {
  card:    '0 2px 8px rgba(0,0,0,0.06)',
  lifted:  '0 8px 32px rgba(0,0,0,0.08)',
  hero:    '0 40px 80px rgba(0,0,0,0.12), 0 0 0 1px rgba(0,0,0,0.08)',
  cta:     '0 4px 20px rgba(196,101,74,0.27)',  // primary @ 27%
}
```

For CTA glow in dark mode, use `shadow-cta` unchanged — the primary is the same hue.

### 4.3 Layout Spacing

- Section vertical padding: `py-20 md:py-24`
- Section horizontal: `px-5 sm:px-8 lg:px-20`
- Max content width: `max-w-[1200px] mx-auto`
- Narrow content (FAQ, CTA): `max-w-[700px]` or `max-w-[560px]`
- Gap between feature rows: `gap-20`
- Card interior padding: `p-4` (compact) / `p-7` (standard) / `p-8` (pricing)

---

## 5. Component Patterns

### 5.1 Primary Button

```html
<button class="
  inline-flex items-center justify-center
  bg-primary hover:bg-primary-dark
  text-white font-bold text-[17px]
  px-9 py-4 rounded-button
  shadow-cta transition
  hover:-translate-y-px
  focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-2 focus-visible:ring-offset-bg
">
  Empieza gratis
</button>
```

### 5.2 Secondary Button

```html
<button class="
  inline-flex items-center justify-center
  bg-transparent text-heading
  border-2 border-primary/20 hover:border-primary
  font-semibold px-7 py-3.5 rounded-button
  transition
">
  Ver cómo funciona ↓
</button>
```

### 5.3 Card

```html
<article class="
  bg-surface rounded-card p-4
  shadow-card
  text-sm
">
  …
</article>
```

### 5.4 Pedido card (key pattern — used throughout)

```html
<article class="bg-surface rounded-card p-4 shadow-card">
  <div class="flex items-center justify-between mb-1">
    <span class="font-bold text-heading">Doña Carmen</span>
    <span class="badge-pagado text-[11px] font-semibold px-2 py-0.5 rounded-pill">
      Pagado
    </span>
  </div>
  <p class="text-body leading-relaxed">2 kg tamales verdes + 1 kg rajas</p>
  <div class="flex items-center justify-between mt-1.5 text-xs text-muted">
    <span>sáb 3pm</span>
    <span class="font-bold text-heading">$650</span>
  </div>
</article>
```

### 5.5 Section Header

```html
<header class="mb-10 md:mb-14 text-center">
  <h2 class="font-serif font-bold text-3xl md:text-[42px] tracking-tight text-heading">
    El cambio que se siente
  </h2>
  <p class="mt-3 text-base text-muted max-w-prose mx-auto">
    …
  </p>
</header>
```

### 5.6 Pricing Card (Popular variant)

```html
<div class="
  relative flex-1 min-w-[300px] max-w-[380px]
  bg-surface rounded-panel p-8
  border-2 border-primary
  shadow-[0_8px_32px_rgba(var(--color-primary)/0.13)]
">
  <span class="
    absolute -top-3 right-5
    bg-primary text-white text-[11px] font-bold uppercase tracking-[0.05em]
    px-3.5 py-1 rounded-pill
  ">Popular</span>
  …
</div>
```

### 5.7 FAQ Accordion

```html
<details class="group border-b border-separator">
  <summary class="
    list-none flex items-center justify-between
    py-5 cursor-pointer
    font-semibold text-heading
  ">
    ¿Cobran comisión sobre mis ventas?
    <span class="text-primary text-2xl transition-transform group-open:rotate-45">+</span>
  </summary>
  <p class="pb-5 text-body leading-relaxed">…</p>
</details>
```

Use native `<details>` for progressive enhancement. Animate `max-height` via CSS `interpolate-size: allow-keywords` or a Headless UI disclosure if you need fine control.

---

## 6. Dark Mode

### 6.1 Strategy

- **Class-based** (`darkMode: 'class'`) — flip `dark` on `<html>`.
- **Three-state toggle**: Auto (default) → Light → Dark. Persist choice in `localStorage('theme')`.
- Detect system preference via `matchMedia('(prefers-color-scheme: dark)')` when mode is `auto`.

### 6.2 Inline script (runs before React hydrates — no FOUC)

```html
<script>
  (function() {
    const stored = localStorage.getItem('theme'); // 'light' | 'dark' | 'auto' | null
    const system = window.matchMedia('(prefers-color-scheme: dark)').matches;
    const isDark = stored === 'dark' || ((stored === 'auto' || !stored) && system);
    if (isDark) document.documentElement.classList.add('dark');
  })();
</script>
```

### 6.3 Toggle Button

Sits in the nav. Icon reflects current state: `◐` (auto) / `☀` (light) / `🌙` (dark). Cycles on click.

```html
<button
  aria-label="Cambiar modo"
  class="
    inline-flex items-center justify-center
    w-9 h-9 rounded-lg
    border border-black/10 dark:border-white/10
    hover:bg-surface transition
  ">
  <!-- icon -->
</button>
```

---

## 7. Palette Switching (Tweak)

Same mechanism as dark mode — a `data-palette="terracotta|nopal"` attribute on `<html>`. Override variables per palette as shown in §2.2. Only these two palettes ship.

---

## 8. Responsive Breakpoints

Default Tailwind breakpoints, with one rule:

> **The hero must look right at `sm:` first.** Desktop is icing.

- Mobile (default): stack everything, phone mockup below copy
- `md:` (768px): two columns return, feature rows alternate sides
- `lg:` (1024px): full horizontal padding, nav links visible
- Below `md`, collapse nav links into a hamburger, keep only the Empieza gratis CTA and the dark-mode toggle visible

---

## 9. Motion

Keep it subtle. Every transition uses:

```css
transition: all 200ms ease;
```

- Buttons: `hover:-translate-y-px` + `hover:bg-primary-dark`
- Cards: no hover state unless the whole card is a link
- Nav: `backdrop-blur-md` appears after `scrollY > 40`
- FAQ chevron: `rotate-45` on open, 300ms
- Pricing toggle: 300ms ease on knob `left`
- Theme/palette swap: `transition-colors duration-[400ms]` on the root

Avoid: long animations, parallax, spring-heavy entrances, auto-playing hero video.

---

## 10. Accessibility Checklist

- Color contrast on body text: ≥ 4.5:1 in both modes (verify `body` on `bg` and `surface`)
- Focus rings: always visible — `focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-2 focus-visible:ring-offset-bg`
- Dark-mode toggle: `aria-label` + live region announcing new mode
- FAQ: native `<details>` or `aria-expanded` if custom
- Phone mockup is decorative — mark its container `aria-hidden="true"` and keep a text description of the feature above it
- All pedido-card examples use real names — keep in examples, but ensure screen readers aren't overwhelmed: wrap illustrative blocks in `role="img"` with `aria-label="Ejemplo de pedido en Kitchef"`

---

## 11. Content Rules (for engineering copy reviews)

- Prices always render with peso sign + MXN implied: `$25`, `$249 MXN/mes`. Never `MX$` or `USD`.
- Names in examples: Carmen, Lupita, Elena, Marisol, Doña + surname variants. Never María García.
- Colonias: Condesa, Del Valle, Chapalita, San Pedro, Roma.
- Numbers: tamal `$25–35`, pastel completo `$650–850`, meal-prep semanal `$1,500–2,500`.
- Banned words: *workflow, optimize, empower, leverage, platform, solution, AI, powered*. Replace each with a concrete verb from her world.

---

## 12. File Structure (suggested)

```
src/
├── app/
│   └── layout.tsx            # injects theme script, html[lang="es"]
├── components/
│   ├── ui/
│   │   ├── Button.tsx
│   │   ├── Card.tsx
│   │   ├── Badge.tsx
│   │   └── ThemeToggle.tsx
│   ├── sections/
│   │   ├── Hero.tsx
│   │   ├── Antes.tsx
│   │   ├── Features.tsx
│   │   ├── SocialProof.tsx
│   │   ├── NoCommissionBanner.tsx
│   │   ├── Pricing.tsx
│   │   ├── FAQ.tsx
│   │   └── FinalCTA.tsx
│   └── phone/
│       └── PhoneMockup.tsx
├── styles/
│   └── globals.css           # token definitions (§2.2, §2.3)
└── lib/
    └── theme.ts              # system-detection + localStorage
```

---

## 13. Quick Reference — Token Cheat Sheet

```
bg-bg                 page background
bg-surface            cards
bg-surface-alt        social-proof & FAQ section bg (cream)
bg-accent-tint        small tinted blocks inside cards

text-heading          serif H1/H2/H3, strong UI
text-body             paragraph copy
text-muted            labels, captions, meta

border-border         card borders
border-separator      in-card dividers, FAQ rows

bg-primary            CTAs, accents, active toggle
text-primary          links, small accent text
border-primary        outlined buttons, popular pricing card
```

---

*Last updated April 2026 — Kitchef v2 reference: `Kitchef Landing Page v2.html`.*
