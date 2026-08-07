import 'package:enough_mail/enough_mail.dart';

/// A configured mailbox. Credentials live only in secure storage on-device.
class RanseAccount {
  RanseAccount({
    required this.id,
    required this.displayName,
    required this.email,
    required this.password,
    required this.imapHost,
    required this.imapPort,
    required this.imapUseSsl,
    required this.smtpHost,
    required this.smtpPort,
    required this.smtpUseSsl,
    String? loginName,
  }) : loginName = loginName ?? email;

  final String id;
  final String displayName;
  final String email;
  final String password;
  final String imapHost;
  final int imapPort;

  /// true = implicit SSL (993); false = STARTTLS on a plain port.
  final bool imapUseSsl;
  final String smtpHost;
  final int smtpPort;

  /// true = implicit SSL (465); false = STARTTLS (587).
  final bool smtpUseSsl;
  final String loginName;

  MailAccount toMailAccount() => MailAccount.fromManualSettings(
        name: displayName.isEmpty ? email : displayName,
        email: email,
        userName: displayName,
        loginName: loginName,
        password: password,
        incomingHost: imapHost,
        incomingPort: imapPort,
        incomingSocketType: imapUseSsl ? SocketType.ssl : SocketType.starttls,
        outgoingHost: smtpHost,
        outgoingPort: smtpPort,
        outgoingSocketType: smtpUseSsl ? SocketType.ssl : SocketType.starttls,
        outgoingClientDomain: email.contains('@') ? email.split('@').last : 'ranse.app',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'email': email,
        'password': password,
        'imapHost': imapHost,
        'imapPort': imapPort,
        'imapUseSsl': imapUseSsl,
        'smtpHost': smtpHost,
        'smtpPort': smtpPort,
        'smtpUseSsl': smtpUseSsl,
        'loginName': loginName,
      };

  factory RanseAccount.fromJson(Map<String, dynamic> json) => RanseAccount(
        id: json['id'] as String,
        displayName: json['displayName'] as String? ?? '',
        email: json['email'] as String,
        password: json['password'] as String,
        imapHost: json['imapHost'] as String,
        imapPort: json['imapPort'] as int,
        imapUseSsl: json['imapUseSsl'] as bool? ?? true,
        smtpHost: json['smtpHost'] as String,
        smtpPort: json['smtpPort'] as int,
        smtpUseSsl: json['smtpUseSsl'] as bool? ?? false,
        loginName: json['loginName'] as String?,
      );
}
