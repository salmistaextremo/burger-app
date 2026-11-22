// app-config.js — Configuración de infraestructura de ESTA instalación.
//
// Cada restaurante que compre la plantilla debe poner aquí su propio proyecto de Supabase.
// Este archivo se sirve al navegador: la "anon key" es pública por diseño; la seguridad
// real depende de las políticas RLS de Supabase, no de ocultar esta clave.
//
// Para una instalación nueva: copia app-config.example.js como app-config.js y rellena los valores.

window.APP_CONFIG = {
  supabaseUrl: 'https://ydueyhlvkmxrsprfgyal.supabase.co',
  supabaseAnonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlkdWV5aGx2a214cnNwcmZneWFsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMwMzMxMDEsImV4cCI6MjEwODYwOTEwMX0.Ha_3BJngwg4motQb0NgeoslDCJsfR-nbkxWnfbFj6rM',
  // Opcional: endpoint de la tasa USD -> Bs
  rateApiUrl: 'https://ve.dolarapi.com/v1/dolares/oficial',
  // Clave pública VAPID para notificaciones push (la privada va en Vercel)
  vapidPublicKey: 'BDHlAuQ02TPgvwGnMg3ds61dqO51iNRG-Z0MxK9-5m5qvBA1f-Z-qt7cdHAPjtWRfsV1eB5MigqFn5FET3Yjctw'
};
