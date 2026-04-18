const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

// Initialize Firebase Admin SDK
admin.initializeApp();

/**
 * sendGeofenceAlert
 * High-performance Firestore trigger for Safe-Kid project.
 * Listens for new alert items and dispatches secure FCM push notifications.
 */
exports.sendGeofenceAlert = onDocumentCreated({
    document: "alerts/{pairingCode}/items/{alertId}",
    region: "us-central1" // Change this if your Firebase project is in a different region
}, async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
        console.log("No data associated with the event");
        return;
    }

    const data = snapshot.data();
    const pairingCode = event.params.pairingCode;

    // RULE: Only dispatch PUSH for confirmed Geofence Exits
    if (data.type !== "GEOFENCE_EXIT") {
        console.log(`Skipping push for alert type: ${data.type}`);
        return;
    }

    try {
        console.log(`Processing Exit Alert for code: ${pairingCode}`);

        // 1. Fetch the Guardian associated with this Pairing Code
        // We query by the role and the pairingCode generated at registration
        const guardianSnapshot = await admin.firestore()
            .collection("users")
            .where("role", "==", "guardian")
            .where("pairingCode", "==", pairingCode)
            .limit(1)
            .get();

        if (guardianSnapshot.empty) {
            console.error(`Security Warning: No guardian found for pairing code ${pairingCode}`);
            return;
        }

        const guardianData = guardianSnapshot.docs[0].data();
        const fcmToken = guardianData.fcmToken;

        if (!fcmToken) {
            console.log("Guardian located, but FCM Token is missing from profile.");
            return;
        }

        // 2. Construct the high-priority FCM payload
        const payload = {
            token: fcmToken,
            notification: {
                title: data.title || "⚠️ child safety alert",
                body: data.message || "your child has left the safe zone.",
            },
            android: {
                priority: "high",
                notification: {
                    sound: "default",
                    channelId: "high_importance_channel",
                    clickAction: "FLUTTER_NOTIFICATION_CLICK"
                }
            },
            data: {
                alertId: event.params.alertId,
                pairingCode: pairingCode,
                click_action: "FLUTTER_NOTIFICATION_CLICK"
            }
        };

        // 3. Dispatch the message securelly
        const response = await admin.messaging().send(payload);
        console.log("🚀 FCM Push delivered successfully:", response);

    } catch (error) {
        console.error("🔥 Critical Error in push pipeline:", error);
    }
});
