import 'package:flutter_test/flutter_test.dart';

import 'package:ranse/services/updater.dart';

void main() {
  group('Updater.isNewer', () {
    test('detects newer versions', () {
      expect(Updater.isNewer('0.2.0', '0.1.0'), isTrue);
      expect(Updater.isNewer('1.0.0', '0.9.9'), isTrue);
      expect(Updater.isNewer('0.1.1', '0.1.0'), isTrue);
    });

    test('rejects same or older versions', () {
      expect(Updater.isNewer('0.1.0', '0.1.0'), isFalse);
      expect(Updater.isNewer('0.1.0', '0.2.0'), isFalse);
      expect(Updater.isNewer('0.9.9', '1.0.0'), isFalse);
    });

    test('ignores build metadata after +', () {
      expect(Updater.isNewer('0.2.0', '0.1.0+7'), isTrue);
      expect(Updater.isNewer('0.1.0+9', '0.1.0'), isFalse);
    });
  });
}
