# NutriMind (app Flutter)

App mobile di food tracking macro-first. Backend: Supabase (DB, Auth, RPC, Edge Functions).

## Configurazione

Le chiavi non sono nel codice: vengono passate a build-time.

1. Copia `env/dev.example.json` in `env/dev.json` (ignorato da git).
2. Inserisci la **anon/publishable key** del progetto DEV
   (Dashboard Supabase > Project Settings > API).
   **Mai** la secret/service_role key: l'app si rifiuta di partire se la riceve.
3. Avvia:

```bash
flutter pub get
flutter run --dart-define-from-file=env/dev.json
```

Per PROD crea `env/prod.json` con URL e chiave di `ynnlfxgehbtlneiknrfr`.

## Funzionalità

**Paziente** (schede Diario · Alimenti · Progressi · Profilo)
- Diario per giorno: registrazione da ricerca, barcode, pasti salvati o copia dal
  giorno prima; modifica dei grammi; obiettivi giornalieri e per pasto dal piano.
- Alimenti: preferiti, pasti salvati, ricerca locale + Open Food Facts su richiesta,
  alimento personale se il prodotto non esiste; dettaglio con valori completi,
  Nutri-Score, NOVA, ingredienti e allergeni.
- Progressi: aderenza al piano, giorni registrati e serie, kcal giornaliere rispetto
  all'obiettivo, medie dei macro (7 / 30 giorni).
- Profilo: preferenze e restrizioni, collegamento al nutrizionista, consensi GDPR.
- Notifiche in-app (realtime) e push FCM; commenti del nutrizionista nel diario.

**Nutrizionista**
- Pazienti ordinati per attenzione; per ciascuno aderenza, diario con commenti,
  restrizioni (con consenso), piano attuale, nuovo piano, scollegamento.
- Codici invito, verifica professionale, nuovi alimenti e porzioni (se verificato).

## Notifiche push (Firebase Cloud Messaging)

Opzionali: senza configurazione l'app usa solo le notifiche in-app.

1. Crea un progetto su https://console.firebase.google.com e aggiungi una **web app**
   (e le app Android/iOS se servono).
2. Copia i valori della config in `env/dev.json` (`FIREBASE_API_KEY`, `FIREBASE_APP_ID`,
   `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_PROJECT_ID`, `FIREBASE_AUTH_DOMAIN`,
   `FIREBASE_STORAGE_BUCKET`) e, per il web, in `web/firebase-config.js`.
3. Web: Cloud Messaging > Certificati push web > genera la chiave e mettila in
   `FIREBASE_VAPID_KEY`.
4. Backend: Impostazioni progetto > Account di servizio > Genera nuova chiave privata,
   e salva il JSON intero come secret `FIREBASE_SERVICE_ACCOUNT` delle Edge Functions
   Supabase (usato da `send-notification`, API FCM HTTP v1).

Dopo il login l'app registra il token del dispositivo in `device_tokens`; al logout
lo rimuove.

## Integrazione Supabase

- Client unico: `lib/core/supabase.dart`.
- Accesso ai dati: `lib/core/food_service.dart` (solo RPC e tabelle protette da RLS).
- Errori normalizzati: `lib/core/app_error.dart` (messaggi per 401/403/404/429/5xx,
  refresh della sessione una volta dopo un 401).
- Barcode: `get_food_by_barcode` → se assente, Edge Function `import-off-barcode`
  → rilettura con `get_food`. Open Food Facts non viene mai chiamato dall'app.
- Ricerca: `search_foods` con debounce di 500 ms.
