import 'package:flutter/material.dart';

import '../models/account.dart';
import '../services/account_store.dart';
import '../services/discovery.dart';
import '../services/notifier.dart';

class AccountSetupScreen extends StatefulWidget {
  const AccountSetupScreen({super.key});

  @override
  State<AccountSetupScreen> createState() => _AccountSetupScreenState();
}

class _AccountSetupScreenState extends State<AccountSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Manual override fields
  final _imapHostController = TextEditingController();
  final _imapPortController = TextEditingController(text: '993');
  final _smtpHostController = TextEditingController();
  final _smtpPortController = TextEditingController(text: '587');
  bool _manual = false;
  bool _imapSsl = true;
  bool _smtpSsl = false;

  bool _busy = false;
  bool _obscure = true;
  String _status = '';
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _imapHostController.dispose();
    _imapPortController.dispose();
    _smtpHostController.dispose();
    _smtpPortController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
      _status = 'Checking the mail server…';
    });

    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;

    try {
      final DiscoveredConfig config;
      if (_manual) {
        config = DiscoveredConfig(
          imapHost: _imapHostController.text.trim(),
          imapPort: int.tryParse(_imapPortController.text.trim()) ?? 993,
          imapUseSsl: _imapSsl,
          smtpHost: _smtpHostController.text.trim(),
          smtpPort: int.tryParse(_smtpPortController.text.trim()) ?? 587,
          smtpUseSsl: _smtpSsl,
        );
      } else {
        config = await Discovery.discover(
          email,
          password,
          onStatus: (status) {
            if (mounted) setState(() => _status = status);
          },
        );
      }

      final account = RanseAccount(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        displayName: _nameController.text.trim(),
        email: email,
        password: password,
        imapHost: config.imapHost,
        imapPort: config.imapPort,
        imapUseSsl: config.imapUseSsl,
        smtpHost: config.smtpHost,
        smtpPort: config.smtpPort,
        smtpUseSsl: config.smtpUseSsl,
      );
      await AccountStore.instance.add(account);
      await Notifier.requestPermission();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on DiscoveryException catch (e) {
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _error = 'Could not sign in. Check the details and try again.\n$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Add account')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Sign in with the email address and password from your '
              'hosting provider. Ranse finds the server settings for you.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Your name (shown to recipients)',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Email address'),
              validator: (v) {
                final value = v?.trim() ?? '';
                if (value.isEmpty) return 'Enter your email address';
                final parts = value.split('@');
                if (parts.length != 2 ||
                    parts[0].isEmpty ||
                    !parts[1].contains('.')) {
                  return 'That does not look like an email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Password',
                suffixIcon: IconButton(
                  icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Enter the password' : null,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Set server settings manually'),
              value: _manual,
              onChanged: (v) => setState(() => _manual = v),
            ),
            if (_manual) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _imapHostController,
                      decoration: const InputDecoration(
                          labelText: 'Incoming (IMAP) host'),
                      validator: (v) => _manual && (v?.trim().isEmpty ?? true)
                          ? 'Required'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _imapPortController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Port'),
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('IMAP uses SSL (port 993)'),
                value: _imapSsl,
                onChanged: (v) => setState(() => _imapSsl = v),
              ),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _smtpHostController,
                      decoration: const InputDecoration(
                          labelText: 'Outgoing (SMTP) host'),
                      validator: (v) => _manual && (v?.trim().isEmpty ?? true)
                          ? 'Required'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _smtpPortController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Port'),
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('SMTP uses SSL (port 465)'),
                subtitle: const Text('Off = STARTTLS (port 587)'),
                value: _smtpSsl,
                onChanged: (v) => setState(() => _smtpSsl = v),
              ),
            ],
            const SizedBox(height: 16),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: scheme.error),
                ),
              ),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 12),
                        Flexible(child: Text(_status)),
                      ],
                    )
                  : const Text('Sign in'),
            ),
          ],
        ),
      ),
    );
  }
}
