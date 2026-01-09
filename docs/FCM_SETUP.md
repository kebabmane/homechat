# Firebase Cloud Messaging (FCM) Setup Guide

This guide walks you through setting up push notifications for HomeChat using Firebase Cloud Messaging (FCM). FCM enables push notifications when users are away from the local network.

> **Note:** FCM is optional. HomeChat works without it using WebSocket-based real-time notifications when connected to your local network.

## Prerequisites

- A Google account
- Access to the [Firebase Console](https://console.firebase.google.com/)
- Admin access to your HomeChat server

---

## Step 1: Create a Firebase Project

1. Go to the [Firebase Console](https://console.firebase.google.com/)
2. Click **Add project**
3. Enter a project name (e.g., "HomeChat")
4. Choose whether to enable Google Analytics (optional)
5. Click **Create project**

---

## Step 2: Enable Cloud Messaging API (v1)

The FCM v1 API should be enabled by default for new projects. To verify:

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your Firebase project
3. Navigate to **APIs & Services** > **Enabled APIs**
4. Search for "Firebase Cloud Messaging API"
5. Ensure it shows as **Enabled**

> **Important:** The legacy FCM API was deprecated in June 2024. HomeChat uses the FCM v1 API exclusively.

---

## Step 3: Create a Service Account

### Option A: Via Firebase Console (Recommended)

1. In the Firebase Console, go to **Project Settings** (gear icon)
2. Select the **Service accounts** tab
3. Click **Generate new private key**
4. Confirm by clicking **Generate key**
5. Save the downloaded JSON file securely

### Option B: Via Google Cloud Console (Custom Permissions)

1. Go to [Google Cloud Console](https://console.cloud.google.com/) > **IAM & Admin** > **Service Accounts**
2. Click **+ Create Service Account**
3. Enter a name (e.g., "homechat-fcm")
4. Click **Create and Continue**
5. In "Grant this service account access to project":
   - Select role: **Firebase Cloud Messaging API Admin**
   - (Not "Firebase Cloud Messaging Admin" - that's different!)
6. Click **Done**
7. Click on the new service account
8. Go to **Keys** tab > **Add Key** > **Create new key**
9. Select **JSON** and click **Create**
10. Save the downloaded file securely

---

## Step 4: Configure HomeChat Server

You have two options for configuring FCM credentials:

### Option A: Rails Credentials (Recommended for Production)

1. Edit your Rails credentials:
   ```bash
   EDITOR="nano" bin/rails credentials:edit
   ```

2. Add the FCM configuration:
   ```yaml
   fcm:
     project_id: "your-firebase-project-id"
     service_account_json:
       type: "service_account"
       project_id: "your-firebase-project-id"
       private_key_id: "key-id-from-json"
       private_key: "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
       client_email: "firebase-adminsdk-xxxxx@your-project.iam.gserviceaccount.com"
       client_id: "123456789"
       auth_uri: "https://accounts.google.com/o/oauth2/auth"
       token_uri: "https://oauth2.googleapis.com/token"
       auth_provider_x509_cert_url: "https://www.googleapis.com/oauth2/v1/certs"
       client_x509_cert_url: "https://www.googleapis.com/robot/v1/metadata/x509/..."
   ```

3. Save and close the editor

### Option B: Environment Variables

Set these environment variables:

```bash
export FCM_PROJECT_ID="your-firebase-project-id"
export FCM_SERVICE_ACCOUNT_JSON='{"type":"service_account",...}'
```

For Docker, add to your `.env` file or docker-compose.yml.

---

## Step 5: Configure iOS App

### 5.1 Add Firebase SDK

The iOS app already includes push notification support. You need to add your Firebase configuration:

1. In Firebase Console, go to **Project Settings**
2. Under "Your apps", click **Add app** > **iOS**
3. Enter the bundle ID: `com.homechat.ios`
4. Download `GoogleService-Info.plist`
5. Add it to your Xcode project in the `HomeChatIOS` folder

### 5.2 Enable Push Notifications in Xcode

1. Open the project in Xcode
2. Select the HomeChatIOS target
3. Go to **Signing & Capabilities**
4. Click **+ Capability**
5. Add **Push Notifications**
6. Add **Background Modes** and enable:
   - Remote notifications
   - Background fetch

### 5.3 Create APNs Key

1. Go to [Apple Developer Portal](https://developer.apple.com/account/resources/authkeys/list)
2. Click **Keys** > **+** (Create a Key)
3. Name it (e.g., "HomeChat Push")
4. Enable **Apple Push Notifications service (APNs)**
5. Click **Register**
6. Download the `.p8` file (you can only download it once!)
7. Note the **Key ID**

### 5.4 Upload APNs Key to Firebase

1. In Firebase Console, go to **Project Settings**
2. Select the **Cloud Messaging** tab
3. Under "Apple app configuration", click **Upload**
4. Upload your `.p8` file
5. Enter the **Key ID** and **Team ID**

---

## Step 6: Configure Android App (Optional)

The Android app already has FCM configured. If you're using a different Firebase project:

1. In Firebase Console, go to **Project Settings**
2. Under "Your apps", click **Add app** > **Android**
3. Enter the package name: `com.homechat.android`
4. Download `google-services.json`
5. Replace the existing file in `homechat-android/app/`

---

## Step 7: Verify Configuration

### Check Server Configuration

```bash
bin/rails runner "puts FcmNotificationService.fcm_configured?"
```

Should output `true` if configured correctly.

### Test Notification

1. Log in to HomeChat on your mobile device
2. Verify the FCM token is registered:
   ```bash
   bin/rails runner "puts User.where.not(fcm_token: nil).count"
   ```
3. Background the app
4. Send a message from another user
5. You should receive a push notification

### Check Server Logs

Look for FCM-related log entries:
```bash
grep "FCM:" log/production.log
```

---

## Troubleshooting

### "FCM: Authentication failed"

- Verify your service account JSON is correctly formatted
- Ensure the service account has the "Firebase Cloud Messaging API Admin" role
- Check that the project ID matches

### "FCM: Token invalid, removing from user"

- The device's FCM token has expired or been invalidated
- User needs to re-open the app to register a new token
- This is normal behavior

### No notifications received

1. Check the app has notification permissions enabled
2. Verify the APNs key is uploaded to Firebase (iOS)
3. Ensure the app is properly backgrounded (not force-closed)
4. Check Firebase Console > Cloud Messaging for delivery reports

### iOS-specific issues

- Ensure `GoogleService-Info.plist` is in the app bundle
- Verify Push Notifications capability is enabled
- Check APNs key is uploaded with correct Key ID and Team ID

---

## Notification Types

HomeChat sends the following types of push notifications:

| Type | Trigger | Title | Body |
|------|---------|-------|------|
| `new_message` | New message in channel | Channel name | "username: message" |
| `direct_message` | New DM | Sender username | Message content |
| `mention` | User @mentioned | "username mentioned you" | "in #channel: message" |
| `channel_invite` | Invited to channel | "Channel Invitation" | "username invited you to join channel" |

All notifications include data payload with `channel_id`, `message_id`, and other context for deep linking.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    HomeChat Server                       │
│                                                          │
│  Message Created (after_create_commit)                  │
│       ↓                                                  │
│  send_push_notifications()                               │
│       ├── Channel/DM notifications                       │
│       └── Mention notifications (if @username found)     │
│       ↓                                                  │
│  FcmNotificationService                                  │
│       ↓                                                  │
│  Authenticate with Service Account                       │
│       ↓                                                  │
│  POST to FCM v1 API                                      │
└─────────────────────────────────────────────────────────┘
                          ↓
              ┌───────────────────────┐
              │   Firebase Cloud      │
              │   Messaging Service   │
              └───────────────────────┘
                    ↓           ↓
            ┌───────────┐ ┌───────────┐
            │   APNs    │ │  Android  │
            │  (iOS)    │ │   GCM     │
            └───────────┘ └───────────┘
                    ↓           ↓
            ┌───────────┐ ┌───────────┐
            │  iPhone   │ │  Android  │
            │   App     │ │   App     │
            └───────────┘ └───────────┘
```

---

## Security Considerations

- **Never commit** your service account JSON to version control
- Store credentials in Rails encrypted credentials or secure environment variables
- The service account JSON contains a private key - treat it like a password
- Rotate your service account key periodically
- Use separate Firebase projects for development and production

---

## Additional Resources

- [Firebase Cloud Messaging Documentation](https://firebase.google.com/docs/cloud-messaging)
- [FCM HTTP v1 API Reference](https://firebase.google.com/docs/cloud-messaging/send/v1-api)
- [FCM v1 API Codelab](https://firebase.google.com/codelabs/use-the-fcm-http-v1-api-with-oauth-2-access-tokens)
- [Apple Push Notification Service](https://developer.apple.com/documentation/usernotifications)
