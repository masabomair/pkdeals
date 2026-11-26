// Firebase project settings for Sale Mela.
//
// These values are not secret: Firebase identifies the project with them and
// protects data with security rules (see firestore.rules in the repo root).
// Fill them in from Firebase console → Project settings → Your apps.
// While apiKey is empty, the app runs without login and analytics.

const firebaseApiKey = 'AIzaSyDdJt2E9H-brhnLog0LnrC6VTzyZT_WjGc';
const firebaseProjectId = 'salemela-3f741';
const firebaseSenderId = '501898722076'; // "messagingSenderId"
const firebaseAuthDomain =
    'salemela-3f741.firebaseapp.com'; // usually <projectId>.firebaseapp.com
const firebaseStorageBucket = 'salemela-3f741.firebasestorage.app';
const firebaseWebAppId = '1:501898722076:web:338251f9734908ba2058d9'; // "appId" of the web app (1:...:web:...)
const firebaseAndroidAppId = '1:501898722076:android:ec2d258534eea8242058d9'; // App ID of the Android app (1:...:android:...)
const firebaseMeasurementId =
    'G-7SJHWQSPBH'; // "measurementId" (G-...), for web analytics

bool get firebaseConfigured =>
    firebaseApiKey.isNotEmpty && firebaseProjectId.isNotEmpty;
