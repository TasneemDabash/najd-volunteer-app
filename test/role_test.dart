import 'package:flutter_test/flutter_test.dart';
import 'package:najd_volunteer/models/call_session.dart';
import 'package:najd_volunteer/models/task_model.dart';
import 'package:najd_volunteer/models/user_role.dart';

void main() {
  group('UserRole', () {
    test('volunteer / support / admin parse from canonical strings', () {
      expect(UserRole.fromString('volunteer'), UserRole.volunteer);
      expect(UserRole.fromString('support'), UserRole.support);
      expect(UserRole.fromString('admin'), UserRole.admin);
    });

    test('falls back to volunteer for unknown or null', () {
      expect(UserRole.fromString(null), UserRole.volunteer);
      expect(UserRole.fromString('wizard'), UserRole.volunteer);
    });

    test('value matches enum name', () {
      expect(UserRole.volunteer.value, 'volunteer');
      expect(UserRole.support.value, 'support');
      expect(UserRole.admin.value, 'admin');
    });
  });

  group('TaskStatus', () {
    test('parses canonical names', () {
      expect(TaskStatus.fromString('pending'), TaskStatus.pending);
      expect(TaskStatus.fromString('active'), TaskStatus.active);
      expect(TaskStatus.fromString('completed'), TaskStatus.completed);
    });

    test('defaults to pending on invalid input', () {
      expect(TaskStatus.fromString(null), TaskStatus.pending);
      expect(TaskStatus.fromString('weird'), TaskStatus.pending);
    });
  });

  group('CallType / CallStatus', () {
    test('CallType handles unknown gracefully', () {
      expect(CallType.fromString('video'), CallType.video);
      expect(CallType.fromString('voice'), CallType.voice);
      expect(CallType.fromString(null), CallType.voice);
    });

    test('CallStatus values match enum names', () {
      expect(CallStatus.ringing.value, 'ringing');
      expect(CallStatus.ended.value, 'ended');
      expect(CallStatus.declined.value, 'declined');
    });

    test('CallStatus.fromString defaults to ended', () {
      expect(CallStatus.fromString(null), CallStatus.ended);
      expect(CallStatus.fromString('???'), CallStatus.ended);
      expect(CallStatus.fromString('ringing'), CallStatus.ringing);
    });
  });
}
