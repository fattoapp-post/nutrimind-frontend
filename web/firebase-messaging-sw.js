// Service worker per le notifiche push su web (Firebase Cloud Messaging).
// La configurazione è in firebase-config.js (stessi valori FIREBASE_* di
// env/dev.json).
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');
importScripts('./firebase-config.js');

if (self.FIREBASE_CONFIG && self.FIREBASE_CONFIG.apiKey) {
  firebase.initializeApp(self.FIREBASE_CONFIG);
  // Le notifiche con payload `notification` vengono mostrate dal browser
  // quando l'app è in background.
  firebase.messaging();
}
