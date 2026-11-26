# APK Android (Capacitor)

Esta carpeta agrega una envoltura Capacitor para instalar la app como APK Android.

## Compilar

El APK se compila en GitHub Actions (no requiere Android Studio local):

1. Sube los cambios a `main`.
2. GitHub → **Actions → Android APK**.
3. Espera el job y descarga el artefacto **dlv-food-debug-apk**.
4. Instala `app-debug.apk` en el teléfono (permitiendo “orígenes desconocidos”).

También se puede ejecutar manualmente con **Run workflow**.

## Compilar en local

Requiere JDK 21 y Android SDK:

```bash
npm install
npm run prepare:www
npx cap add android
node scripts/patch-android.js
npx cap sync android
cd android && ./gradlew assembleDebug
```

El APK queda en `android/app/build/outputs/apk/debug/app-debug.apk`.

## Qué incluye

- Envoltura WebView con la app del cliente (`index.html`).
- Geolocalización con `@capacitor/geolocation` y permisos de ubicación.
- Enlaces de WhatsApp con `@capacitor/browser` (Custom Tab).
- Los archivos `admin.html` y `repartidor.html` también se copian a `www`, pero el APK inicia en la app del cliente. Para el admin o el repartidor se puede generar otro APK cambiando el `startPath` o el `appId`.

## Limitaciones importantes

- **Web Push no funciona dentro del WebView de Android.** Las notificaciones push del admin/repartidor siguen funcionando en la PWA instalada desde Chrome, no en este APK. Para push nativo hay que agregar `@capacitor/push-notifications` + Firebase (FCM).
- WhatsApp se abre en un Custom Tab; si Android muestra “Abrir en app”, hay que tocarlo una vez.
- Un APK **debug** es para pruebas. Para Play Store hace falta firmarlo en release (keystore) y generar AAB.
- Si se actualiza la web, hay que volver a compilar el APK (o usar `server.url` apuntando a producción para cargar siempre la versión web).

## Alternativa si el push es imprescindible

Una **TWA (Trusted Web Activity)** con Bubblewrap envuelve la PWA en Chrome y conserva service worker, Web Push y geolocalización. Es la opción recomendada si el APK debe recibir las notificaciones push actuales.
