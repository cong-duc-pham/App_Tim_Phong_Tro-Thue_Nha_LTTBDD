import 'package:flutter_test/flutter_test.dart';
import 'package:ung_dung_tim_kiem_tro/core/utils/validators.dart';

void main() {
  group('Validators', () {
    test('accepts valid account fields', () {
      expect(Validators.email('teacher@example.com'), isNull);
      expect(Validators.phone('0912345678'), isNull);
      expect(Validators.password('123456'), isNull);
      expect(Validators.otp('123456'), isNull);
    });

    test('rejects invalid account fields', () {
      expect(Validators.email('invalid-email'), isNotNull);
      expect(Validators.phone('123'), isNotNull);
      expect(Validators.password('123'), isNotNull);
      expect(Validators.otp('12ab56'), isNotNull);
    });
  });
}
