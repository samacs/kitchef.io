# 13 · Tu plan

[← Volver al índice](README.md) · Anterior: [Clientes](12-clientes.md)

---

## Para qué sirve

Kitchef tiene dos planes — Gratis y Pro. Esta pantalla te dice en
cuál estás, qué incluye, y cómo cambiar.

## Cuándo usarla

- **Una sola vez** — al decidir si pasarte a Pro.
- **Cuando renueves o canceles** la suscripción.

No es una pantalla diaria.

## Los dos planes

### Gratis · $0 / mes

Para arrancar y probar. Incluye:
- Tu storefront completo (kitchef.mx/tu-cocina).
- Hasta **20 pedidos al mes**.
- Recetario completo.
- Kanban de pedidos.
- Producción + lista de compras.
- Reportes básicos.
- Soporte por correo.

**Limitación principal:** 20 pedidos al mes. El pedido 21 te
muestra un aviso *"Te quedaste sin pedidos en este mes — pásate a
Pro para continuar"*. El pedido sigue capturándose, pero te invita
a actualizar.

### Pro · $150 / mes

Para cocinas que ya rodaron. Incluye todo lo del plan Gratis, sin
límite de pedidos, **más**:

- Pedidos ilimitados.
- Inventario y lotes (capítulo 10) — sólo disponible en Pro.
- Reportes avanzados (Tu menú con segmentación, Finanzas con
  utilidad neta).
- Costos fijos (capítulo 5).
- Recetas avanzadas con desglose de costo.
- Exportar a CSV.
- Soporte por WhatsApp.
- Sin marca "Hecho con Kitchef" en tu storefront.

> **Sin comisión por venta — siempre.** Kitchef nunca te cobra un
> porcentaje de lo que vendes. La cuota mensual es el único costo.

## Cómo se ve la pantalla

Vive en `/subscription`. Te muestra:

1. **Tu plan actual** con un badge (Gratis o Pro).
2. **Próxima factura** (si estás en Pro) con fecha y monto.
3. **Botón** que cambia según el contexto:
   - Gratis → **Pásate a Pro**.
   - Pro → **Cancelar plan**.
4. **Historial de pagos** (si tuviste algunos) con descarga de
   recibo.

## Cómo pasarte a Pro

1. Ve a **Plan** en el menú lateral.
2. Toca **Pásate a Pro**.
3. Te lleva a Stripe Checkout — captura tarjeta.
4. Confirmas.
5. Stripe te cobra el primer mes; tu cuenta queda en Pro al instante.

Los cambios son inmediatos:
- La sección **Funciones avanzadas** en `/account/edit` queda
  desbloqueada.
- El recordatorio de "20 pedidos" desaparece.
- Los reportes muestran las gráficas completas.

> **Pago seguro:** Kitchef nunca toca tu tarjeta. La maneja Stripe
> directamente. Si tu tarjeta cambia, lo actualizas en Stripe (te
> mandamos un link al cambiar).

## Cómo cancelar Pro

1. Ve a **Plan**.
2. Toca **Cancelar plan**.
3. Confirma.

Lo que pasa:
- Sigues en Pro hasta que termine el periodo ya pagado.
- No te volvemos a cobrar.
- Cuando termine, pasas automáticamente a Gratis.
- Tus datos quedan intactos. Tu storefront sigue funcionando.
- Las funciones Pro (inventario, reportes avanzados) se ocultan
  pero no se borran. Si vuelves a Pro, todo está donde lo dejaste.

> Si cancelas dentro de las primeras 24 horas del primer pago,
> contacta soporte para reembolso completo.

## Facturación

Stripe genera la factura cada mes. Si necesitas factura fiscal en
México (CFDI), por ahora no la generamos automáticamente — pídela
a soporte con tu RFC y razón social.

## Errores comunes

| Pasó esto | Hacer esto |
|---|---|
| Pasé a Pro pero el inventario no aparece. | Ve a `/account/edit` y activa el toggle **Inventario y lotes**. Pro habilita la opción; tú decides cuándo activarla. |
| Mi tarjeta venció. | Stripe te avisa por correo. Actualiza tu tarjeta en el portal de Stripe (link en el correo). |
| Cancelé y se borró todo. | No se borra nada. Vuelve a Pro y todo regresa. |
| El cobro mensual no llegó pero estoy en Pro. | Stripe a veces tarda en cobrar (1-3 días). Si pasan 5 días sin cobro, contacta soporte. |
| Quiero pagar anual con descuento. | Por ahora sólo mensual. Si te interesa anual, escríbenos para cotizar. |

## Cuándo pasarte a Pro

Pásate cuando:

- Pasaste de 20 pedidos al mes (la propia pantalla te avisa).
- Vas a activar inventario.
- Quieres ver utilidad neta y márgenes detallados.
- Tu tiempo de soporte vale más que $150/mes.

No te apresures. Si llevas 5 pedidos al mes, Gratis te sobra.

## Próximos pasos

- **[Volver al índice](README.md)** — has terminado el manual.
  ¡Felicidades!

---

[← Volver al índice](README.md) · Anterior: [Clientes](12-clientes.md)
