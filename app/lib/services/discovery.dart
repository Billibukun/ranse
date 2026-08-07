import 'package:enough_mail/enough_mail.dart';

class DiscoveredConfig {
  DiscoveredConfig({
    required this.imapHost,
    required this.imapPort,
    required this.imapUseSsl,
    required this.smtpHost,
    required this.smtpPort,
    required this.smtpUseSsl,
  });

  final String imapHost;
  final int imapPort;
  final bool imapUseSsl;
  final String smtpHost;
  final int smtpPort;
  final bool smtpUseSsl;
}

class DiscoveryException implements Exception {
  DiscoveryException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Finds working IMAP/SMTP settings for a cPanel-style mailbox by actually
/// logging in with the given credentials. cPanel convention puts both services
/// on `mail.<domain>`, with the bare domain as fallback.
class Discovery {
  static const _timeout = Duration(seconds: 12);

  static Future<DiscoveredConfig> discover(
    String email,
    String password, {
    void Function(String status)? onStatus,
  }) async {
    final parts = email.split('@');
    if (parts.length != 2 || parts[1].isEmpty) {
      throw DiscoveryException('That does not look like an email address.');
    }
    final domain = parts[1].toLowerCase();
    final hosts = ['mail.$domain', domain];

    String? imapHost;
    var imapPort = 993;
    var imapUseSsl = true;
    Object? lastError;

    for (final host in hosts) {
      onStatus?.call('Trying incoming server $host…');
      try {
        await _probeImap(host, 993, ssl: true, email: email, password: password);
        imapHost = host;
        break;
      } catch (e) {
        lastError = e;
      }
      try {
        await _probeImap(host, 143,
            ssl: false, email: email, password: password);
        imapHost = host;
        imapPort = 143;
        imapUseSsl = false;
        break;
      } catch (e) {
        lastError = e;
      }
    }

    if (imapHost == null) {
      final hint = lastError is ImapException
          ? 'The server rejected the login — check the email and password.'
          : 'Could not reach a mail server for $domain.';
      throw DiscoveryException(hint);
    }

    // SMTP: same host as IMAP, 587 STARTTLS preferred, 465 SSL fallback.
    for (final (port, ssl) in [(587, false), (465, true)]) {
      onStatus?.call('Trying outgoing server $imapHost:$port…');
      try {
        await _probeSmtp(imapHost, port,
            ssl: ssl, email: email, password: password, domain: domain);
        return DiscoveredConfig(
          imapHost: imapHost,
          imapPort: imapPort,
          imapUseSsl: imapUseSsl,
          smtpHost: imapHost,
          smtpPort: port,
          smtpUseSsl: ssl,
        );
      } catch (_) {
        // try next candidate
      }
    }

    throw DiscoveryException(
        'Incoming mail works, but no outgoing (SMTP) server accepted the '
        'login on $imapHost. Enter the settings manually.');
  }

  static Future<void> _probeImap(
    String host,
    int port, {
    required bool ssl,
    required String email,
    required String password,
  }) async {
    final client = ImapClient(isLogEnabled: false);
    try {
      await client.connectToServer(host, port, isSecure: ssl, timeout: _timeout);
      if (!ssl) {
        await client.startTls();
      }
      await client.login(email, password);
      await client.logout();
    } finally {
      await client.disconnect();
    }
  }

  static Future<void> _probeSmtp(
    String host,
    int port, {
    required bool ssl,
    required String email,
    required String password,
    required String domain,
  }) async {
    final client = SmtpClient(domain, isLogEnabled: false);
    try {
      await client.connectToServer(host, port,
          isSecure: ssl, timeout: _timeout);
      await client.ehlo();
      if (!ssl) {
        final response = await client.startTls();
        if (!response.isOkStatus) {
          throw DiscoveryException('STARTTLS refused on $host:$port');
        }
      }
      try {
        await client.authenticate(email, password, AuthMechanism.plain);
      } on SmtpException {
        await client.authenticate(email, password, AuthMechanism.login);
      }
      await client.quit();
    } finally {
      await client.disconnect();
    }
  }
}
