/* Firebase Cloud Messaging service worker for Flutter web.
   Required so getToken() does not fail with unsupported MIME type. */
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyCqLObK4oe-Y7huBVTsB1UmSl8EGqxUu6w',
  authDomain: 'open-space-parking.firebaseapp.com',
  projectId: 'open-space-parking',
  storageBucket: 'open-space-parking.firebasestorage.app',
  messagingSenderId: '794049298844',
  appId: '1:794049298844:web:e2d18b28cd68232fb68859',
});

firebase.messaging();
