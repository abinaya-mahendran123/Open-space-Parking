const fs = require('fs');
const path = require('path');

let messaging = null;
let initError = null;

function loadServiceAccount() {
  const inline = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (inline && inline.trim()) {
    return JSON.parse(inline);
  }

  const accountPath =
    process.env.FIREBASE_SERVICE_ACCOUNT_PATH ||
    process.env.GOOGLE_APPLICATION_CREDENTIALS ||
    '';
  if (accountPath && fs.existsSync(accountPath)) {
    return JSON.parse(fs.readFileSync(accountPath, 'utf8'));
  }

  return null;
}

function getMessaging() {
  if (messaging) return messaging;
  if (initError) return null;

  try {
    const admin = require('firebase-admin');
    if (admin.apps.length > 0) {
      messaging = admin.messaging();
      return messaging;
    }

    const serviceAccount = loadServiceAccount();
    if (!serviceAccount) {
      initError = new Error(
        'FIREBASE_SERVICE_ACCOUNT_PATH or FIREBASE_SERVICE_ACCOUNT_JSON is not set.',
      );
      return null;
    }

    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId:
        process.env.FIREBASE_PROJECT_ID ||
        serviceAccount.project_id ||
        'open-space-parking',
    });
    messaging = admin.messaging();
    return messaging;
  } catch (error) {
    initError = error;
    return null;
  }
}

function isConfigured() {
  return getMessaging() != null;
}

function collectionForRecipientType(recipientType) {
  switch (recipientType) {
    case 'employee':
      return 'employees';
    case 'land_owner':
    case 'landOwner':
      return 'users';
    case 'vehicle_owner':
    case 'vehicleOwner':
      return 'users';
    default:
      return 'users';
  }
}

async function lookupFcmToken(db, recipientId, recipientType) {
  const { ObjectId } = require('mongodb');
  const collectionName = collectionForRecipientType(recipientType);

  let doc = null;
  try {
    doc = await db.collection(collectionName).findOne({
      _id: new ObjectId(recipientId),
    });
  } catch (_) {
    doc = await db.collection(collectionName).findOne({
      _id: recipientId,
    });
  }

  if (!doc) return null;
  return doc.fcmToken || doc.fcm_token || null;
}

async function sendPushNotification({
  db,
  recipientId,
  recipientType,
  title,
  body,
  route,
  referenceId,
}) {
  const fcm = getMessaging();
  if (!fcm) {
    return {
      sent: false,
      reason: initError?.message || 'FCM is not configured on the backend.',
    };
  }

  const token = await lookupFcmToken(db, recipientId, recipientType);
  if (!token) {
    return {
      sent: false,
      reason: 'Recipient has no FCM device token (app not opened yet).',
    };
  }

  const data = {
    title: String(title || ''),
    body: String(body || ''),
    recipientId: String(recipientId || ''),
    recipientType: String(recipientType || ''),
  };
  if (route) data.route = String(route);
  if (referenceId) data.referenceId = String(referenceId);

  try {
    await fcm.send({
      token,
      notification: {
        title: data.title || 'Open Space Parking',
        body: data.body,
      },
      data,
      android: { priority: 'high' },
      apns: {
        payload: {
          aps: {
            sound: 'default',
          },
        },
      },
    });
    return { sent: true };
  } catch (error) {
    return {
      sent: false,
      reason: error.message || 'FCM send failed.',
    };
  }
}

module.exports = {
  sendPushNotification,
  isConfigured,
};
