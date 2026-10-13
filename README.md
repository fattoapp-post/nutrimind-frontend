# NutriMind (app Flutter)

App mobile di food tracking macro-first. Backend: Supabase (DB, Auth, RPC, Edge Functions).

## Configurazione

Le chiavi non sono nel codice: vengono passate a build-time.

1. Copia `env/dev.example.json` in `env/dev.json` (ignorato da git).
2. Inserisci la **anon/publishable key** del progetto DEV
   (Dashboard Supabase > Project Settings > API).
   **Mai** la secret/service_role key: l'app si rifiuta di partire se la riceve.
Per PROD crea `env/prod.json` con URL e chiave di `ynnlfxgehbtlneiknrfr`.

## Avviare l'app

**Indicare sempre il dispositivo.** Senza `-d`, Flutter elenca anche
Windows ed Edge e chiede quale usare; scegliendo Windows la build
fallisce, perché serve il carico "Desktop development with C++" di
Visual Studio e il Developer Mode attivo per i symlink. Oggi il web è
l'unico bersaglio che compila.

```bash
flutter pub get
flutter run -d chrome --dart-define-from-file=env/dev.json
```

Apre da sé una finestra di Chrome. Due cose da sapere:

- **è lento ad avviarsi**, e il tempo sta tutto in *"Waiting for
  connection from debug service on Chrome"*: circa 100 secondi dopo un
  `pub get`, circa 35 a cache calda. Sta compilando l'app in
  JavaScript, non è bloccato;
- **non stampa l'indirizzo dell'app.** Gli unici URL a terminale sono
  quelli del debug service e di DevTools: aprirli non porta all'app, e
  chiudendo la finestra aperta da Flutter non resta nessun indirizzo a
  cui tornare.

Se si vuole invece un indirizzo stabile, da riaprire quando si vuole e
nel browser che si preferisce:

```bash
flutter run -d web-server --web-port=8080 --dart-define-from-file=env/dev.json
```

Serve l'app su **`http://localhost:8080`**. Così com'è si lega a
`0.0.0.0`, quindi rispondono sia `localhost` sia `127.0.0.1`, e l'app è
raggiungibile anche dal telefono sulla stessa rete (comodo, ma tenere
presente che la espone a tutta la rete locale).

**Non aggiungere `--web-hostname=localhost`**: con quel parametro il
server si lega al *solo* loopback IPv6 e `http://127.0.0.1:8080` smette
di rispondere senza spiegare il perché. Verificato: `localhost` e
`[::1]` danno 200, `127.0.0.1` non si connette. Se serve il solo IPv4,
`--web-hostname=127.0.0.1`.

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
