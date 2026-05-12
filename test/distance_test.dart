import 'package:flutter_test/flutter_test.dart';
import 'package:najd_volunteer/models/app_location.dart';

void main() {
  group('haversineKm', () {
    test('returns 0 for identical points', () {
      final d = haversineKm(24.7136, 46.6753, 24.7136, 46.6753);
      expect(d, closeTo(0.0, 1e-6));
    });

    test('Riyadh ↔ Jeddah is ~850 km', () {
      // Riyadh roughly 24.7136 N, 46.6753 E. Jeddah ~21.4858 N, 39.1925 E.
      final d = haversineKm(24.7136, 46.6753, 21.4858, 39.1925);
      expect(d, greaterThan(840));
      expect(d, lessThan(870));
    });

    test('1 degree of latitude ≈ 111 km', () {
      final d = haversineKm(0, 0, 1, 0);
      expect(d, greaterThan(110));
      expect(d, lessThan(112));
    });

    test('is symmetric', () {
      final ab = haversineKm(10, 20, 30, 40);
      final ba = haversineKm(30, 40, 10, 20);
      expect(ab, closeTo(ba, 1e-9));
    });
  });

  group('AppLocation', () {
    test('displayName combines name and region', () {
      const l = AppLocation(id: '1', name: 'Riyadh', region: 'Center');
      expect(l.displayName, 'Riyadh · Center');
    });

    test('falls back to name when region is empty', () {
      const l = AppLocation(id: '1', name: 'Riyadh');
      expect(l.displayName, 'Riyadh');
    });

    test('fromJson parses string and numeric coordinates', () {
      final fromNums = AppLocation.fromJson({
        'id': 'x',
        'name': 'A',
        'region': 'B',
        'latitude': 12.5,
        'longitude': '34.6',
        'is_active': true,
      });
      expect(fromNums.latitude, 12.5);
      expect(fromNums.longitude, 34.6);
      expect(fromNums.isActive, true);
    });
  });
}
