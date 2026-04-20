# Kitchef — Product Requirements Document

**Version:** 1.0 (v1 scope)
**Owner:** Saul
**Domains:** kitchef.mx (primary, MX-facing) · kitchef.io (reserved for future)
**Date:** April 2026

---

## 1. Vision

**Kitchef turns a home kitchen into a real business.** It gives Mexican home-food operators — the tamaleras, pasteleras, and meal-prep cooks who sell from their kitchens via WhatsApp and Instagram — a single, phone-first tool to take orders, know their real costs, plan production, and grow without chaos.

The name carries the promise: *de cocinera a chef de tu propio negocio.* The software honors her kitchen as her business instead of trying to professionalize it away.

---

## 2. Problem & Opportunity

### The problem
The Mexican home-food economy is large, informal, and growing. A typical operator runs her business across:

- WhatsApp threads with 40+ unread messages
- A spiral notebook with crossed-out numbers
- The phone's calculator app, used daily to guess at margins
- Post-it notes for "Doña Carmen wants 2 kg de tamales el sábado"
- Her own memory for who paid a deposit, who still owes, what the tía needs for the XV años

She loses orders she forgot to write down. She underprices dishes because she has never properly costed them. She promises deliveries to three different colonias at the same time. When ingredient prices jump, she has no way to tell which of her dishes just stopped being profitable.

### Why now
- Instagram and WhatsApp Business made it easy for home cooks to *acquire* customers.
- Nothing has made it easy for them to *run* the business behind those customers.
- The cottage-food cohort accelerated during and after the pandemic and is now the primary income for many households — serious tools are overdue.
- Incumbents are wrong for this audience: restaurant POS is overkill and too expensive; marketplaces (Rappi, UberEats) take 20–30% and own the customer; generic SaaS is in English and priced in USD.

### The wedge
We are not replacing a working system. We are organizing chaos. That means willingness-to-pay shows up faster than in any "replace the POS" product, and word-of-mouth (one tamalera tells another) is the natural distribution channel.

---

## 3. Target User

### Primary persona — "Elena"

- 34 years old, lives in Guadalajara, Puebla, Monterrey, or CDMX suburbs
- Runs her operation from home, sometimes with her mother or sister helping
- 8–40 regular clients, mostly repeat buyers from Instagram and WhatsApp
- Android phone, mobile data, uses Instagram daily, WhatsApp constantly
- Speaks Spanish (Mexican). Reads English with some difficulty.
- Is not a "solopreneur" — she is *una señora con su negocio*, or a young mom who started selling meal-preps and can't keep up
- Suspicious of anything that looks like a gringo startup. Trusts recommendations from other cooks.
- Has never formally priced a dish. Prices by feel or by copying a neighbor.
- Has never filed an SAT declaration for her kitchen business. May or may not want to. Not our problem in v1.

### Secondary persona (future) — "Fonda owner"
- Runs a small fonda or taquería with 1–4 employees
- Uses a paper notebook + cash drawer. Son-in-law does the taxes.
- Not a v1 target. The product scales *into* her when her home-kitchen customer grows.

### Who this is NOT for (v1)
- Restaurant chains
- Ghost kitchens running multiple brands
- Food trucks with POS hardware needs
- Bakeries with walk-in retail counters (different workflow)
- English-speaking or US-based operators (wrong market, wrong tone)

---

## 4. Product Scope (v1)

Kitchef v1 is a phone-first operations suite with five integrated modules, sharing a single data model. Every feature is designed to work on a $3,000 MXN Android phone on 4G.

### Module 1 — Order intake & client management
- Each operator gets a public shareable URL at the root level: `kitchef.mx/cocina-de-elena`
  - Clean, memorable, easy to say out loud at the mercado or write on a business card
  - Reserved top-level paths (`/precios`, `/registro`, `/panel`, etc.) are enforced at the model level; see TRD §8
- Public order form: client fills in name, phone, what they want, delivery date, address
- Orders land in a kanban board: *pedido → confirmado → en producción → listo → entregado → pagado*
- Client directory: preferences ("no le gusta el cilantro"), allergies, colonia, birthday, past orders
- Per-client WhatsApp deep-link: one tap to message the client with a pre-filled confirmation

### Module 2 — Recipe & ingredient cost engine (the quiet superpower)
- Ingredient library with unit prices the operator maintains manually (kilo de masa $18, litro de aceite $42, docena de huevo $58)
- Recipe cards reference components (ingredients and/or other recipes) with quantities
- Cost-per-portion calculates automatically
- When an ingredient price changes, every recipe that uses it — directly or transitively — updates immediately
- Dashboard flag: "Estos platillos cayeron debajo de tu margen objetivo"

#### Progressive decomposition (the adaptive UX)

Operators live on a spectrum. Some want to list *Tamales — $25* and never think about cost breakdowns. Others want to control the whole production tree down to grams of *manteca*. Kitchef supports both **from day one**, but the UI adapts to where the operator is on that spectrum.

**How it works, from the operator's perspective:**

1. **The simple path — flat recipes.** By default, a new recipe is a simple card: name, price, photo, optional category. No cost, no ingredients, no decomposition. The operator can run her whole business this way forever and never see a "component" or an "ingredient." She gets order management, client notes, production planning — just no cost engine.

2. **The gentle invitation.** On the recipe detail view (and on the dashboard once she has 3+ recipes), a soft prompt appears: *"¿Quieres saber cuánto te cuesta este platillo?"* Clicking it launches a focused, step-by-step onboarding flow — not a settings toggle, but a guided first-decomposition.

3. **First decomposition.** The flow walks her through decomposing *one* recipe into ingredients. She adds the ingredients she bought this week (with quantities and prices), then says how much of each goes into one portion. The moment she finishes, the system shows her real cost and margin, probably for the first time in her business's life. *"Tu tamal te cuesta $8.40. Lo vendes en $25. Tu margen es 66%."*

4. **Unlocking the advanced mode.** Completing that first decomposition flips `use_composable_recipes` to `true` on her account. From this moment on, her UI quietly changes:
   - Every recipe now shows its cost alongside its price
   - A *"Descomponer"* action appears on every recipe that is still flat
   - When adding a component, she can choose another **recipe** (not just an ingredient) — e.g., "mi masa" as a component of "mi tamal verde"
   - Recipes themselves can be nested arbitrarily deep (tamal → masa → harina + manteca + polvo de hornear; salsa verde → tomate verde + cebolla + chile serrano; etc.)

5. **The operators who want everything from day one.** Power users can skip the gentle path entirely. The onboarding survey asks once: *"¿Quieres controlar tus costos desde el principio?"* A *"Sí, quiero controlar mis recetas al detalle"* answer enables advanced mode immediately and seeds the recipe form with the full component picker.

**What "advanced mode" actually adds to the UI:**
- Recipes can be marked *"saleable"* (appears on the menu) or *"interna"* (used only as a component of other recipes — e.g., a base masa, a mother salsa, a rendered lard)
- Recipe forms include a component picker that can select either an ingredient OR another recipe
- Recipe detail views show a decomposition tree visualization
- The cost engine resolves transitive costs (a change to the price of corn flour updates the cost of masa, which updates the cost of every tamal recipe that uses masa)
- Reports include "ingredient impact analysis" — which raw ingredients drive the most total cost across her operation

**What stays simple, always:**
- If an operator never flips into advanced mode, she never sees the word "component," never sees a tree view, never sees a recipe-as-ingredient picker
- If an operator flips into advanced mode but only decomposes one recipe, the rest of her recipes stay flat and simple — no forced migration
- The sale price of a recipe is always a single number she controls directly; cost is *calculated*, never imposed
- When a recipe is used as a component in another recipe, the parent always uses the component's **cost**, never the component's sale price (even if the component is also saleable)

### Module 3 — Menu engineering (the insight layer)
- Stars / plowhorses / puzzles / dogs matrix, translated into plain language
- *"Tus chiles rellenos son tu platillo estrella — se venden mucho y dejan buen margen."*
- *"Tu flan se vende bien pero casi no deja; considera subirlo a $90 o sacarlo de la carta."*
- Works for 6–10 items (home operator) and naturally scales to 30+ (future fonda tier)

### Module 4 — Production planning & delivery routing
- Weekly production view: consolidates shopping list from all confirmed orders
- Prep timeline: "hacer masa domingo 5pm para entregas lunes"
- Delivery slot capacity: Saturdays 10am–6pm, max 5 orders/slot (uses `interval_set` to prevent overbooking)
- Orders grouped by colonia for route efficiency: "Roma/Condesa sábado, Coyoacán/Del Valle domingo"

### Module 5 — Finance lite
- Weekly and monthly view of ingresos, costos, margen bruto
- Payment tracking: deposits (anticipos) and final payments per order
- **Deliberately simple** — no double-entry, no SAT/CFDI integration at launch
- Export to Excel for the señora's contador (via `caxlsx`)

### Cross-cutting features
- Public storefront page with menu, prices, hours, WhatsApp link
- WhatsApp deep-link integration (no API required for v1)
- QR code generator for the operator's URL (for business cards, flyers) via `rqrcode`
- Real-time order updates via Turbo broadcasts (new pedido → appears on her board without refresh)
- Daily digest email (optional) via Resend
- In-app notifications via Noticed
- Mobile-first responsive design — everything must work beautifully on a 360px viewport

---

## 5. Non-Goals (v1)

Explicitly **not** building in v1, even if tempting:

- **SAT / CFDI / facturación**. Too complex, too risky, and the operator mostly doesn't need it yet. This becomes a Pro-tier upsell later.
- **Payment processing.** Mercado Pago and SPEI happen outside Kitchef; we just record that payment was received. Integrating Mercado Pago is v1.5.
- **POS hardware / cash drawer / receipt printer.** Not relevant for home operators.
- **Inventory with real-time depletion.** The operator buys ingredients for the week from the shopping list; we don't track depletion between orders. v2 feature.
- **Multi-employee roles & permissions.** Single-operator workspaces only. Teams come with the fonda tier.
- **Multi-currency.** MXN only. (Technically we support multi-currency via `money-rails`, but MXN is the default and the only one exposed in UI.)
- **English UI.** Spanish-first, Spanish-only. Translations come later if they come at all.
- **WhatsApp Business API integration.** v2. We use deep links (`https://wa.me/`) in v1.
- **Marketplace functionality.** Kitchef is *her* tool for *her* customers. We do not aggregate cooks into a marketplace. Ever.
- **Nutrition facts, macros, dietary analysis.** Not relevant to this audience.
- **Complex tax handling.** IVA toggle exists as a setting but no tax-authority integrations.
- **Native mobile apps.** Responsive PWA is enough for v1.

---

## 6. User Stories

### As an operator setting up for the first time:
- I sign up with email + password, choose my kitchen name (*Cocina de Elena*), and get a URL (`kitchef.mx/cocina-de-elena`)
- I'm asked one question during onboarding: *"¿Quieres controlar tus costos desde el principio?"*
  - If I say **no** (or skip), I'm dropped into simple mode: add recipes with just a name, photo, and price
  - If I say **yes**, advanced mode is enabled and I see the component picker on every recipe form
- I add my 8 signature dishes with photos and prices
- I share my URL on my Instagram bio and my WhatsApp business profile

### As a simple-mode operator (most users):
- I manage my 8 dishes as flat cards — name, price, photo. That's it.
- A week later I see a gentle prompt on my dashboard: *"¿Quieres saber cuánto te cuesta cada platillo?"*
- I tap it, pick my most-sold dish, and walk through a guided decomposition
- The system shows me my real cost and margin for the first time. I'm surprised.
- From this moment on, *"Descomponer"* appears on my other recipes. I can decompose them at my own pace — or not at all.

### As an advanced-mode operator (power user from day one):
- During onboarding I select *"Sí, quiero controlar mis recetas al detalle"*
- My first recipe form shows a full component picker right away
- I create *masa* as an **internal recipe** (not for sale) with corn flour, lard, baking powder, water
- I create *tamal verde* as a **saleable recipe** that uses *masa* + *salsa verde* + chicken filling as components
- When corn flour goes up 15%, my tamal cost updates automatically — the change propagates through the tree

### As an operator taking orders:
- A client opens my URL, picks 2 kg de tamales verdes, fills her name and WhatsApp
- The order lands on my board as *pedido*
- I WhatsApp her from the order card with one tap, confirm the deposit, mark as *confirmado*
- As the delivery day approaches, I see my production plan and shopping list
- I deliver, mark as *entregado*, record the final payment, mark as *pagado*

### As an operator trying to grow:
- End of month, I see I made $14,200 MXN, my costs were $5,800, my margen is 59%
- Menu engineering tells me my flan is a "dog" and I should either reprice or drop it
- (If I'm in advanced mode) I also see that corn flour is my single biggest cost driver across the whole operation — and I realize I could negotiate a better price with the *molino* if I commit to a larger weekly order
- I see December is coming and the *rosca de reyes* template is suggested
- I try it, sell 40 roscas, and learn Kitchef seeded me a working recipe card + pricing template

### As a client of the operator:
- I open `kitchef.mx/cocina-de-elena` from a WhatsApp link
- I see her menu with photos, prices, delivery areas, and next available date
- I place an order in under 90 seconds
- I get a WhatsApp confirmation from her with all the details
- I can check the status of my order at `kitchef.mx/cocina-de-elena/pedido/ord_xyz`

---

## 7. UX & Tone Principles

### Language & voice
- **Spanish only (es-MX)** across all UI, emails, and notifications
- Second-person familiar: *tú*, never *usted*
- Plain Mexican Spanish: *pedido* not *orden*, *anticipo* not *depósito*, *colonia* not *zip code*, *platillo* not *producto*
- No English loanwords where Spanish works. No *"optimiza tu workflow"* energy.
- No "AI-powered" anywhere, even if AI is used internally
- Money always in MXN with `$` (not MX$)
- Real Mexican names in examples (Carmen, Lupita, Elena, Marisol — not María García)
- Real neighborhoods in placeholders (Condesa, Del Valle, Chapalita, San Pedro)
- Realistic 2026 prices (a tamal is $25–35)

### Visual direction
- Warm off-white background (masa, not Figma blank)
- Primary color: deep terracotta / mole / nopal green (grounded, confident)
- One accent for CTAs. No purple, no 3D blobs, no chef hats.
- Warm serif for headlines (Tiempos, Recoleta, or similar) + clean sans for UI (Inter)
- Photography over illustration where possible; editorial hand-drawn when not
- Generous whitespace. Phone-first.

### Interaction principles
- Every destructive action has a confirm step
- Every status change broadcasts in real-time to the operator's other open tabs/devices (Turbo Streams)
- Every form is one-thumb-typeable on a 360px phone
- Every piece of data the operator enters is editable without leaving the context
- Loading states are short, meaningful, and in Spanish

---

## 8. Pricing & Monetization

### Free tier — *Plan Básico*
- Up to **20 pedidos/month**
- 1 operator (1 user)
- Unlimited clients, recipes, ingredients
- Basic reports
- Kitchef branding on public storefront
- **$0**

### Pro tier — *Plan Profesional*
- Unlimited pedidos
- Menu engineering insights
- Production planning with delivery slot capacity
- Excel export
- Remove Kitchef branding from public storefront
- QR code generator
- Priority email support
- **$249 MXN/month** (or $2,490 MXN/year, 2 months free)

### Fonda tier (future — v2.0)
- Multi-employee (up to 5 users)
- Per-role permissions (cashier, cook, admin)
- CFDI/facturación integration
- POS-style sales importer
- Inventory with depletion
- **$749 MXN/month**

### Payment rails (v1)
- Stripe for card payments in MXN
- Mercado Pago integration in v1.5

### Absolute commitment
**Kitchef never takes a commission on the operator's sales.** Ever. This must be visible on the pricing page. The operator's relationship with her customer is hers; we sell her tools, not access to her.

---

## 9. Success Metrics

### Activation (first 7 days)
- **% of signups who add 3+ recipes within 7 days** — target: 60%
- **% of signups who receive their first pedido via their public URL within 14 days** — target: 35%
- Time to first cost-per-portion calculation (among operators who engage with decomposition) — target: under 10 minutes from first tap on *"¿Quieres saber cuánto te cuesta?"*
- **% of signups who complete first decomposition within 30 days** — target: 40% (this is the quiet-superpower conversion; measured via `composable_recipes_unlocked_at`)

### Retention
- **Weekly active operators** (operators who logged in OR received an order in the last 7 days)
- **Monthly retention at 30/60/90 days** — target: 55 / 40 / 30%
- Median orders processed per operator per week at day 60 — target: 5+

### Revenue
- **Free → Pro conversion within 60 days** — target: 15%
- **MRR growth** (goal: $50k MXN MRR by month 6 post-launch)
- **Gross churn** — target: under 8% monthly

### Health
- Orders processed per operator per month (the thing that actually creates value)
- NPS surveyed in-app at day 30

---

## 10. Roadmap

### v1.0 — MVP (ships first)
All five modules above, free + Pro tiers, Stripe, Resend, Turbo real-time, public storefronts, WhatsApp deep links, QR codes.

### v1.1 — First polish (weeks 4–8 post-launch)
- Seasonal templates library (*rosca de reyes*, *tamales de Navidad*, *pastel de XV años*)
- Daily/weekly digest emails
- SMS reminders for delivery day (via Twilio, already in reference Gemfile)
- Birthday reminders for the operator's clients

### v1.2 — Instagram & growth (weeks 8–16)
- Instagram post generator from recipe cards (auto-formatted menu posts)
- Referral program (*invita a una cocinera, ambas ganan un mes*)
- Public directory of Kitchef kitchens (opt-in, SEO play)
- Review / rating system for repeat clients

### v1.5 — Mercado Pago & payments (month 4–6)
- Mercado Pago checkout for anticipos
- SPEI payment link generation
- Payment reconciliation dashboard

### v2.0 — Fonda tier (month 6–12)
- Multi-employee accounts
- CFDI integration (via Facturapi or similar)
- Sales importer (daily CSV from POS)
- Inventory with depletion
- Expanded analytics

### v3.0 — Beyond Mexico (year 2)
- Kitchef Colombia (.co), Chile (.cl), Peru (.pe) — same product, localized currencies and tone
- WhatsApp Business API integration

---

## 11. Risks & Open Questions

### Risks
- **Willingness to pay at $249 MXN/month is unproven for this audience.** Mitigation: free tier with generous limit (20 pedidos) + clear upgrade moments.
- **Acquisition is WhatsApp/Instagram organic, which is slow.** Mitigation: seed 20–30 founding operators with direct outreach before public launch; invest in content SEO around *"cómo vender comida desde casa"*.
- **Support load for non-technical users could be high.** Mitigation: ruthless UX simplicity, in-app WhatsApp support channel, video walkthroughs.
- **WhatsApp changes its deep-link or Business API terms.** Mitigation: we rely only on public `wa.me` URLs in v1; no API lock-in.
- **Competitor shows up (likely from Brazil where this is a slightly older market).** Mitigation: Mexican-ness is a moat — tone, vocabulary, photography, `.mx` — not features.

### Open questions
- Should the free tier be ad-supported (we show Kitchef branding on public storefront) or truly free with just the order limit?
  - *Proposed: order limit only, branding as Pro upgrade signal. Never third-party ads.*
- Do operators want us to handle their Mercado Pago integration, or just generate a link?
  - *Proposed: link generation in v1.5, full integration in v1.6.*
- How do we handle operators who grow out of "home cook" into "small fonda"? Auto-upgrade? Manual?
  - *Proposed: manual. We never upsell aggressively. When she asks, we help.*

---

## 12. Brand Promises (copy for the product)

These should appear verbatim or near-verbatim across the product and marketing:

- *Kitchef — la cocina de tu negocio.*
- *Tu cocina, tu negocio, en un solo lugar.*
- *De cocinera a chef de tu propio negocio.*
- *Nunca cobramos comisión sobre tus ventas. Tus clientes son tuyos.*
- *Hecho en México, en español, en pesos.*

---

**End of PRD.**
