import 'package:flutter/material.dart';

import '../models/account.dart';
import '../services/account_store.dart';
import '../services/discovery.dart';
import '../services/notifier.dart';
import '../theme.dart';

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
    final ranse = context.ranse;
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(26, 8, 26, 30),
            children: [
              if (canPop)
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.arrow_back, size: 22),
                    onPressed:
                        _busy ? null : () => Navigator.of(context).pop(),
                  ),
                ),
              const SizedBox(height: 26),
              Text('Ranse',
                  style: context.disp(size: 42, italic: true)),
              const SizedBox(height: 4),
              Text(
                'YOUR MAIL, DELIVERED',
                style: TextStyle(
                  fontSize: 10.5,
                  letterSpacing: 2.4,
                  fontWeight: FontWeight.w700,
                  color: ranse.brass,
                ),
              ),
              const SizedBox(height: 26),
              Glass(
                radius: 20,
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _underlineField(
                      label: 'YOUR NAME (SHOWN TO RECIPIENTS)',
                      child: TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        enabled: !_busy,
                        style: const TextStyle(fontSize: 14.5),
                      ),
                    ),
                    _underlineField(
                      label: 'EMAIL ADDRESS',
                      child: TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        enabled: !_busy,
                        style: const TextStyle(fontSize: 14.5),
                        validator: (v) {
                          final value = v?.trim() ?? '';
                          if (value.isEmpty) {
                            return 'Enter your email address';
                          }
                          final parts = value.split('@');
                          if (parts.length != 2 ||
                              parts[0].isEmpty ||
                              !parts[1].contains('.')) {
                            return 'That does not look like an email address';
                          }
                          return null;
                        },
                      ),
                    ),
                    _underlineField(
                      label: 'PASSWORD',
                      child: TextFormField(
                        controller: _passwordController,
                        obscureText: _obscure,
                        enabled: !_busy,
                        style: const TextStyle(fontSize: 14.5),
                        decoration: InputDecoration(
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 19,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Enter the password'
                            : null,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          _error!,
                          style: TextStyle(
                              fontSize: 12.5, color: scheme.error),
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _busy ? null : _save,
                        style: FilledButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _busy
                            ? Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                  const SizedBox(width: 12),
                                  Flexible(
                                      child: Text(_status,
                                          maxLines: 1,
                                          overflow:
                                              TextOverflow.ellipsis)),
                                ],
                              )
                            : const Text('Sign in',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  'Ranse finds your mail server settings automatically.',
                  style: TextStyle(
                      fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Set server settings manually',
                    style: TextStyle(fontSize: 13.5)),
                value: _manual,
                onChanged:
                    _busy ? null : (v) => setState(() => _manual = v),
              ),
              if (_manual) ...[
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _imapHostController,
                        decoration: const InputDecoration(
                            labelText: 'Incoming (IMAP) host',
                            border: UnderlineInputBorder()),
                        validator: (v) =>
                            _manual && (v?.trim().isEmpty ?? true)
                                ? 'Required'
                                : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _imapPortController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Port',
                            border: UnderlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('IMAP uses SSL (port 993)',
                      style: TextStyle(fontSize: 13.5)),
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
                            labelText: 'Outgoing (SMTP) host',
                            border: UnderlineInputBorder()),
                        validator: (v) =>
                            _manual && (v?.trim().isEmpty ?? true)
                                ? 'Required'
                                : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _smtpPortController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Port',
                            border: UnderlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('SMTP uses SSL (port 465)',
                      style: TextStyle(fontSize: 13.5)),
                  subtitle: const Text('Off = STARTTLS (port 587)',
                      style: TextStyle(fontSize: 11.5)),
                  value: _smtpSsl,
                  onChanged: (v) => setState(() => _smtpSsl = v),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _underlineField({required String label, required Widget child}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(color: scheme.outlineVariant, width: 1.2)),
      ),
      padding: const EdgeInsets.only(top: 14, bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w800,
              color: scheme.onSurfaceVariant,
            ),
          ),
          child,
        ],
      ),
    );
  }
}
