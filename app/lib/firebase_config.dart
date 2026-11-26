// Firebase project settings for Sale Mela.
//
// These values are not secret: Firebase identifies the project with them and
// protects data with security rules (see firestore.rules in the repo root).
// Fill them in from Firebase console → Project settings → Your apps.
// While apiKey is empty, the app runs without login and analytics.

const firebaseApiKey = '';
const firebaseProjectId = '';
const firebaseSenderId = ''; // "messagingSenderId"
const firebaseAuthDomain = ''; // usually <projectId>.firebaseapp.com
const firebaseStorageBucket = '';
const firebaseWebAppId = ''; // "appId" of the web app (1:...:web:...)
const firebaseAndroidAppId =
    ''; // App ID of the Android app (1:...:android:...)
const firebaseMeasurementId = ''; // "measurementId" (G-...), for web analytics

bool get firebaseConfigured =>
    firebaseApiKey.isNotEmpty && firebaseProjectId.isNotEmpty;
