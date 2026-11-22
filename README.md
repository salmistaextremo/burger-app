# DLV Food — Plantilla de pedidos (PWA)

Tres aplicaciones web sobre un mismo backend Supabase:

| App | Archivo | Para quién |
|---|---|---|
| Cliente | `index.html` | Quien pide: menú, carrito, checkout, rastreo, calificación |
| Admin | `admin.html` | El restaurante: productos, pedidos, repartidores, reportes, marca |
| Repartidor | `repartidor.html` | El motorizado: pedidos asignados y entregas |

Es una PWA instalable, sin build ni framework: HTML + CSS + JS y Supabase.

## Puesta en marcha

1. **Configura Supabase.** Crea un proyecto y copia `app-config.example.js` como `app-config.js`; rellena `supabaseUrl` y `supabaseAnonKey` (Settings → API).
2. **Importa la base de datos.** El proyecto necesita las tablas `config`, `categories`, `products`, `orders`, `drivers`, los buckets `productos` y `comprobantes`, y las funciones RPC (`verify_driver`, `get_driver_orders`, `mark_order_delivered`, `get_order_by_code`, `confirm_order_received`, `rate_order`). Importa el `supabase/schema.sql` que acompaña a tu licencia (o el respaldo de la base original).
3. **Entra al admin** (`/admin.html`) con el usuario creado en Supabase Auth. La tarjeta **"Configura tu restaurante"** te guía: WhatsApp, marca, pagos, categorías y productos.
4. **Personaliza la marca** en *Negocio → Diseño y Colores*: color principal, color de fondo, logo y paletas rápidas. Se aplica al cliente y al repartidor al recargar.
5. **Despliega en Vercel**: importa el repo, framework "Other", sin build. Las cabeceras de seguridad y la CSP ya están en `vercel.json`.
6. **Instala la PWA** desde el navegador (el service worker se registra solo).

## Qué se configura sin tocar código

- Nombre del negocio, logo (emoji o URL), colores y fondo.
- WhatsApp, teléfono, enlace de mapas, moneda, costo de delivery.
- Días y horarios de atención, tasa de cambio manual.
- Métodos de pago y sus datos (Pago Móvil, transferencia, Zelle, efectivo, tarjeta).
- Categorías, productos, extras, disponibilidad y repartidores.
- **Delivery por distancia**: tarifa Urbana hasta 4 km y Extra Urbana más lejos, calculada con el GPS del cliente. La ubicación de la tienda se configura en el admin.
- Reglas de pago: retiro acepta todos los métodos; delivery solo métodos anticipados (no efectivo/tarjeta) y exige comprobante.

## Qué sí requiere editar archivos

- **Iconos PWA**: `icon-192.png`, `icon-512.png`, `icon-maskable-512.png`, `icon-180.png` y `favicon.ico`. Vienen con el monograma **DLV.**; reemplázalos por el logo del restaurante conservando nombres y tamaños.
- **Textos legales** (`LEGAL_TEXTS` en `index.html`) y textos de bienvenida.
- **Nombre por defecto** en `manifest*.json` y en los `DEFAULT_CONFIG`/`CONFIG` si no usas el admin.

## Estructura

```
index.html                App cliente
admin.html                Panel administrador
repartidor.html           App repartidor
app-config.js             Credenciales de Supabase (editar por instalación)
app-config.example.js     Plantilla de configuración
sw.js                     Service worker (offline + notificaciones)
manifest*.json            Manifests PWA (cliente, admin, repartidor)
vercel.json               CSP y cabeceras de seguridad
icon-*.png, favicon.ico   Iconos
```

## Notas

- La `anon key` de Supabase es pública por diseño. **La seguridad depende de las políticas RLS**: no pongas la tabla `drivers` ni `orders` en lectura abierta.
- El service worker no cachea datos de Supabase (solo el shell y estáticos), así que los pedidos siempre se leen en vivo.
- El `theme_color` del manifest es estático (se usa al instalar); el color de la barra del navegador sí cambia en runtime con el color configurado.
- Seguridad: aplica `supabase/03-driver-auth.sql` para migrar las contraseñas de repartidores a bcrypt con sesiones por token. Las RPC de consulta de pedidos siguen validando solo por código; revisa el checklist de seguridad antes de vender la plantilla.
- Antes de publicar en producción, ejecuta `supabase/diagnostico-seguridad.sql` (solo lectura) y activa RLS según el resultado. El diagnóstico lista RLS, políticas, permisos de `anon` y el estado de la tabla `drivers`.
