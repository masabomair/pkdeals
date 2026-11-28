import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'data.dart';
import 'firebase_config.dart';

/// Optional sign-in (Google or email) with Firebase.
///
/// Signed-in people get a record in Firestore at users/{uid} (name, email,
/// sign-up date, last visit, platform) and their saved items and brand
/// alerts are kept there, so they follow them between phone and laptop.
/// The app owner sees everyone in Firebase console → Authentication → Users.
class Account extends ChangeNotifier {
  static final Account i = Account._();
  Account._();

  bool ready = false;
  User? user;
  StreamSubscription<User?>? _sub;

  bool get enabled => ready;
  bool get signedIn => user != null;

  Future<void> init() async {
    if (!firebaseConfigured) return;
    if (!kIsWeb && firebaseAndroidAppId.isEmpty)
      return; // Android app not registered yet
    try {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: kIsWeb ? firebaseApiKey : firebaseAndroidApiKey,
          appId: kIsWeb ? firebaseWebAppId : firebaseAndroidAppId,
          messagingSenderId: firebaseSenderId,
          projectId: firebaseProjectId,
          authDomain: firebaseAuthDomain.isEmpty ? null : firebaseAuthDomain,
          storageBucket: firebaseStorageBucket.isEmpty
              ? null
              : firebaseStorageBucket,
          measurementId: firebaseMeasurementId.isEmpty
              ? null
              : firebaseMeasurementId,
        ),
      );
      ready = true;
      FirebaseAnalytics.instance.logAppOpen();
      _sub = FirebaseAuth.instance.authStateChanges().listen((u) async {
        user = u;
        notifyListeners();
        if (u != null) await _syncDown(u);
      });
    } catch (e) {
      debugPrint('Firebase not available: $e');
      ready = false;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid);

  /// After sign-in: merge what's on this device with what's in the account.
  Future<void> _syncDown(User u) async {
    try {
      final ref = _doc(u.uid);
      final snap = await ref.get();
      final data = snap.data() ?? {};
      final remoteSaved = List<Map<String, dynamic>>.from(
        (data['saved'] as List? ?? const []).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ),
      );
      final remoteFavs = List<String>.from(
        data['favBrands'] as List? ?? const [],
      );
      await Prefs.mergeFromAccount(remoteSaved, remoteFavs);
      await ref.set({
        'name': u.displayName,
        'email': u.email,
        'photo': u.photoURL,
        'provider': u.providerData.isEmpty
            ? null
            : u.providerData.first.providerId,
        'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
        'lastSeen': FieldValue.serverTimestamp(),
        if (!snap.exists) 'createdAt': FieldValue.serverTimestamp(),
        'saved': Prefs.savedJson.take(200).toList(),
        'favBrands': Prefs.favBrands.toList(),
      }, SetOptions(merge: true));
      FirebaseAnalytics.instance.logLogin(
        loginMethod: u.providerData.isEmpty
            ? 'unknown'
            : u.providerData.first.providerId,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Account sync failed: $e');
    }
  }

  /// Called after saved items or brand alerts change on this device.
  void pushPrefs() {
    final u = user;
    if (!ready || u == null) return;
    _doc(u.uid)
        .set({
          'saved': Prefs.savedJson.take(200).toList(),
          'favBrands': Prefs.favBrands.toList(),
          'lastSeen': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true))
        .catchError((e) => debugPrint('push failed: $e'));
  }

  // ---------------------------------------------------------------- sign-in methods

  bool _gsiReady = false;

  Future<void> signInWithGoogle() async {
    final provider = GoogleAuthProvider()
      ..setCustomParameters({'prompt': 'select_account'});
    if (kIsWeb) {
      await FirebaseAuth.instance.signInWithPopup(provider);
      return;
    }
    // Android: the phone's own Google account picker, then Firebase
    final gsi = GoogleSignIn.instance;
    try {
      if (!_gsiReady) {
        await gsi.initialize(serverClientId: firebaseWebClientId);
        _gsiReady = true;
      }
      final account = await gsi.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) throw StateError('no id token');
      await FirebaseAuth.instance.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw FirebaseAuthException(code: 'canceled');
      }
      // picker not available on this phone: fall back to the browser flow
      await FirebaseAuth.instance.signInWithProvider(provider);
    }
  }

  Future<void> signUpWithEmail(
    String name,
    String email,
    String password,
  ) async {
    final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    if (name.trim().isNotEmpty) {
      await cred.user?.updateDisplayName(name.trim());
      await cred.user?.reload();
      user = FirebaseAuth.instance.currentUser;
      if (user != null) await _syncDown(user!);
    }
    FirebaseAnalytics.instance.logSignUp(signUpMethod: 'password');
  }

  Future<void> logInWithEmail(String email, String password) => FirebaseAuth
      .instance
      .signInWithEmailAndPassword(email: email.trim(), password: password);

  Future<void> resetPassword(String email) =>
      FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!kIsWeb && _gsiReady) {
      try {
        await GoogleSignIn.instance
            .signOut(); // next time the picker asks again
      } catch (_) {}
    }
  }
}

/// Turns Firebase error codes into sentences people can act on.
String authMessage(Object e) {
  if (e is FirebaseAuthException) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address doesn\'t look right.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email or password is wrong. Try again, or reset your password.';
      case 'email-already-in-use':
        return 'An account with this email already exists. Log in instead.';
      case 'weak-password':
        return 'Use a password with at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Wait a minute and try again.';
      case 'network-request-failed':
        return 'No internet connection. Check it and try again.';
      case 'popup-closed-by-user':
      case 'web-context-canceled':
      case 'canceled':
        return 'Sign-in was cancelled.';
      case 'account-exists-with-different-credential':
        return 'This email already signs in another way. Use that method.';
    }
    return e.message ?? 'Sign-in failed. Please try again.';
  }
  return 'Sign-in failed. Please try again.';
}
