import 'package:material_ui/material_ui.dart';

import 'account.dart';
import 'ui.dart';

/// Top of the Profile tab: sign-in buttons, or who is signed in.
class AccountCard extends StatefulWidget {
  const AccountCard({super.key});
  @override
  State<AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends State<AccountCard> {
  bool busy = false;

  @override
  void initState() {
    super.initState();
    Account.i.addListener(_on);
  }

  @override
  void dispose() {
    Account.i.removeListener(_on);
    super.dispose();
  }

  void _on() => setState(() {});

  Future<void> _google() async {
    setState(() => busy = true);
    try {
      await Account.i.signInWithGoogle();
    } catch (e) {
      if (mounted) _toast(context, authMessage(e));
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final r = RC.of(context);
    final u = Account.i.user;
    final box = BoxDecoration(
      color: r.soft,
      borderRadius: BorderRadius.circular(18),
    );

    if (u != null) {
      final name = (u.displayName?.isNotEmpty ?? false)
          ? u.displayName!
          : (u.email ?? 'Signed in');
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: box,
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: r.pink,
              foregroundImage: u.photoURL == null
                  ? null
                  : NetworkImage(u.photoURL!),
              child: Text(
                initials(name),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: r.ink,
                    ),
                  ),
                  if (u.email != null && u.email != name)
                    Text(
                      u.email!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: r.muted),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    'Saved items and alerts sync to this account',
                    style: TextStyle(color: r.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Account options',
              icon: Icon(Icons.more_vert, color: r.ink),
              onSelected: (v) {
                if (v == 'out') Account.i.signOut();
                if (v == 'delete') confirmDeleteAccount(context);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'out', child: Text('Sign out')),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    'Delete my account',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: box,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Sign in to Sale Mela',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: r.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Keep your saved items and brand alerts on every phone and laptop. Browsing works without an account.',
            style: TextStyle(color: r.muted, fontSize: 13.5),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Rang.ink,
              minimumSize: const Size.fromHeight(50),
              side: const BorderSide(color: Color(0xFFDADCE0)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            onPressed: busy ? null : _google,
            icon: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const _GoogleG(),
            label: const Text('Continue with Google'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: r.ink,
              minimumSize: const Size.fromHeight(50),
              side: BorderSide(color: r.ink.withValues(alpha: .25)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            onPressed: busy ? null : () => showEmailAuth(context),
            icon: const Icon(Icons.mail_outline, size: 20),
            label: const Text('Use email instead'),
          ),
        ],
      ),
    );
  }
}

/// The four-colour Google "G", drawn so no image file is needed.
class _GoogleG extends StatelessWidget {
  const _GoogleG();
  @override
  Widget build(BuildContext context) =>
      SizedBox(width: 20, height: 20, child: CustomPaint(painter: _GPainter()));
}

class _GPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final w = s.width;
    final rect = Rect.fromLTWH(w * .1, w * .1, w * .8, w * .8);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * .19;
    const deg = 3.14159265 / 180;
    p.color = const Color(0xFFEA4335);
    c.drawArc(rect, -150 * deg, 110 * deg, false, p);
    p.color = const Color(0xFFFBBC05);
    c.drawArc(rect, 150 * deg, 60 * deg, false, p);
    p.color = const Color(0xFF34A853);
    c.drawArc(rect, 40 * deg, 110 * deg, false, p);
    p.color = const Color(0xFF4285F4);
    c.drawArc(rect, -5 * deg, 45 * deg, false, p);
    c.drawRect(
      Rect.fromLTWH(w * .5, w * .42, w * .42, w * .17),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

/// Asks for confirmation, then deletes the account and its data.
Future<void> confirmDeleteAccount(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Delete your account?'),
      content: const Text(
        'This permanently deletes your Sale Mela account and the saved items '
        'and brand alerts stored with it. This can\'t be undone.\n\n'
        'For your security, you\'ll be asked to sign in once more.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Keep account'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(c).colorScheme.error,
          ),
          onPressed: () => Navigator.pop(c, true),
          child: const Text('Delete account'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  try {
    final done = await Account.i.deleteAccount(
      askPassword: () => _askPassword(context),
    );
    if (context.mounted && done)
      _toast(context, 'Your account and its data were deleted.');
  } catch (e) {
    if (context.mounted) _toast(context, authMessage(e));
  }
}

Future<String?> _askPassword(BuildContext context) {
  final c = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (d) => AlertDialog(
      title: const Text('Confirm your password'),
      content: TextField(
        controller: c,
        obscureText: true,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Password'),
        onSubmitted: (v) => Navigator.pop(d, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(d),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(d, c.text),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
}

void _toast(BuildContext context, String msg) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

Future<void> showEmailAuth(BuildContext context) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  constraints: const BoxConstraints(maxWidth: 560),
  builder: (_) => const EmailAuthSheet(),
);

class EmailAuthSheet extends StatefulWidget {
  const EmailAuthSheet({super.key});
  @override
  State<EmailAuthSheet> createState() => _EmailAuthSheetState();
}

class _EmailAuthSheetState extends State<EmailAuthSheet> {
  bool signUp = false, busy = false, hide = true;
  String? error, info;
  final name = TextEditingController(),
      email = TextEditingController(),
      pass = TextEditingController();
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
      info = null;
    });
    try {
      if (signUp) {
        await Account.i.signUpWithEmail(name.text, email.text, pass.text);
      } else {
        await Account.i.logInWithEmail(email.text, pass.text);
      }
      if (mounted) {
        Navigator.pop(context);
        _toast(
          context,
          signUp ? 'Account created. Welcome to Sale Mela!' : 'Signed in',
        );
      }
    } catch (e) {
      setState(() => error = authMessage(e));
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _reset() async {
    if (!email.text.contains('@')) {
      setState(
        () =>
            error = 'Type your email above first, then tap "Forgot password".',
      );
      return;
    }
    try {
      await Account.i.resetPassword(email.text);
      setState(() {
        error = null;
        info = 'We sent a password reset link to ${email.text.trim()}.';
      });
    } catch (e) {
      setState(() => error = authMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = RC.of(context);
    InputDecoration deco(String label, IconData icon) => InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: r.field,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              signUp ? 'Create your account' : 'Log in with email',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: r.ink,
              ),
            ),
            const SizedBox(height: 16),
            if (signUp) ...[
              TextFormField(
                controller: name,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                decoration: deco('Your name', Icons.person_outline),
              ),
              const SizedBox(height: 10),
            ],
            TextFormField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: deco('Email', Icons.mail_outline),
              validator: (v) =>
                  (v ?? '').contains('@') ? null : 'Enter your email address',
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: pass,
              obscureText: hide,
              autofillHints: [
                signUp ? AutofillHints.newPassword : AutofillHints.password,
              ],
              decoration: deco('Password', Icons.lock_outline).copyWith(
                suffixIcon: IconButton(
                  tooltip: hide ? 'Show password' : 'Hide password',
                  icon: Icon(
                    hide
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(() => hide = !hide),
                ),
              ),
              validator: (v) =>
                  (v ?? '').length >= 6 ? null : 'At least 6 characters',
              onFieldSubmitted: (_) => _submit(),
            ),
            if (!signUp)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: busy ? null : _reset,
                  child: Text(
                    'Forgot password?',
                    style: TextStyle(
                      color: r.pink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (info != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  info!,
                  style: TextStyle(color: r.green, fontWeight: FontWeight.w600),
                ),
              ),
            const SizedBox(height: 14),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: r.pink,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              onPressed: busy ? null : _submit,
              child: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(signUp ? 'Create account' : 'Log in'),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: busy
                  ? null
                  : () => setState(() {
                      signUp = !signUp;
                      error = null;
                      info = null;
                    }),
              child: Text(
                signUp
                    ? 'Already have an account? Log in'
                    : 'New here? Create an account',
                style: TextStyle(color: r.ink, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
