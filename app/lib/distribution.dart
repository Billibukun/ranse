/// Which channel this build ships through. Set at build time:
///
///   flutter build apk --flavor github                 → 'github' (default)
///   flutter build appbundle --flavor play --dart-define=DISTRIBUTION=play
///
/// Google Play policy forbids self-updating outside Play, so the play build
/// disables the in-app updater entirely (Play delivers updates itself).
const String kDistribution =
    String.fromEnvironment('DISTRIBUTION', defaultValue: 'github');

const bool kSelfUpdateEnabled = kDistribution != 'play';
