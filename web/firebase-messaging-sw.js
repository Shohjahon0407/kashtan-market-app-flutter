/* global importScripts, firebase */

importScripts('/firebase-config.js');

// Firebase Messagingni import qilishdan oldin ro'yxatdan o'tkaziladi: aks holda
// SDK notification click'ni ushlab, order deep-linkini yo'qotishi mumkin.
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const data = event.notification.data || {};
  const orderId = data.order_id || data.related_order_id;
  const storeType = data.store_type;
  const target = orderId && storeType
    ? `/#/store/${encodeURIComponent(storeType)}/orders/${encodeURIComponent(orderId)}`
    : '/#/notifications';
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((tabs) => {
      for (const tab of tabs) {
        if ('focus' in tab) {
          tab.navigate(target);
          return tab.focus();
        }
      }
      return clients.openWindow ? clients.openWindow(target) : undefined;
    }),
  );
});

const config = self.BESHKASHTAN_FIREBASE_CONFIG;
if (config && config.apiKey && config.appId && config.messagingSenderId) {
  importScripts(
    'https://www.gstatic.com/firebasejs/11.10.0/firebase-app-compat.js',
  );
  importScripts(
    'https://www.gstatic.com/firebasejs/11.10.0/firebase-messaging-compat.js',
  );

  firebase.initializeApp(config);
  const messaging = firebase.messaging();

  messaging.onBackgroundMessage((payload) => {
    // notification payloadni browser/FCM o'zi ko'rsatadi. Data-only eventda
    // esa persistent lifecycle bildirishnomasini shu yerda chizamiz.
    if (payload.notification) return;
    const data = payload.data || {};
    const title = data.title || "Besh Kashtan";
    const body = data.body || '';
    self.registration.showNotification(title, {
      body,
      icon: '/favicon.svg',
      tag: data.notification_id || data.order_id || undefined,
      data,
    });
  });
}
