import 'package:flutter_test/flutter_test.dart';
import 'package:open_space_parking/core/utils/validators.dart';

void main() {
  group('Validators', () {
    group('email', () {
      test('returns error when empty', () {
        expect(Validators.email(null), 'Email is required');
        expect(Validators.email(''), 'Email is required');
        expect(Validators.email('   '), 'Email is required');
      });

      test('returns error for invalid format', () {
        expect(Validators.email('not-an-email'), 'Enter a valid email address');
        expect(Validators.email('missing@domain'), 'Enter a valid email address');
      });

      test('returns null for valid email', () {
        expect(Validators.email('user@example.com'), isNull);
        expect(Validators.email('  user@test.co  '), isNull);
      });
    });

    group('minLength', () {
      test('returns error when too short', () {
        expect(Validators.minLength('abc', 8), isNotNull);
        expect(Validators.minLength(null, 8), isNotNull);
      });

      test('returns null when long enough', () {
        expect(Validators.minLength('12345678', 8), isNull);
      });
    });

    group('requiredField', () {
      test('returns error when empty', () {
        expect(Validators.requiredField(null), isNotNull);
        expect(Validators.requiredField('  '), isNotNull);
      });

      test('returns null when present', () {
        expect(Validators.requiredField('value'), isNull);
      });
    });

    group('vehicleNumber', () {
      test('returns error when empty and required', () {
        expect(Validators.vehicleNumber(null), isNotNull);
        expect(Validators.vehicleNumber(''), isNotNull);
      });

      test('allows empty when not required', () {
        expect(Validators.vehicleNumber('', required: false), isNull);
      });

      test('returns error for invalid format', () {
        expect(Validators.vehicleNumber('1234'), isNotNull);
        expect(Validators.vehicleNumber('TN09'), isNotNull);
        expect(Validators.vehicleNumber('HELLO WORLD'), isNotNull);
      });

      test('returns null for Indian vehicle numbers', () {
        expect(Validators.vehicleNumber('TN 09 AB 1234'), isNull);
        expect(Validators.vehicleNumber('tn09ab1234'), isNull);
        expect(Validators.vehicleNumber('DL1CAA1234'), isNull);
        expect(Validators.vehicleNumber('22 BH 1234 AA'), isNull);
      });
    });
  });
}
