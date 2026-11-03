import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';

enum FeedbackCategory {
  complaint('complaint', 'Complaint'),
  featureRequest('feature_request', 'Feature request'),
  other('other', 'Other');

  const FeedbackCategory(this.storageValue, this.label);

  final String storageValue;
  final String label;
}

class FeedbackSignInRequiredException implements Exception {
  const FeedbackSignInRequiredException();
}

class FeedbackService {
  FeedbackService({
    Future<void> Function(Map<String, dynamic> row)? insertRow,
    String? Function()? currentUserId,
    String Function()? platform,
    this.submitTimeout = const Duration(seconds: 15),
  })  : _insertRow = insertRow ?? _insertIntoSupabase,
        _currentUserId = currentUserId ?? _sessionUserId,
        _platform = platform ?? _devicePlatform;

  static const _table = 'app_feedback';
  static const int minMessageLength = 10;
  static const int maxMessageLength = 2000;

  final Future<void> Function(Map<String, dynamic> row) _insertRow;
  final String? Function() _currentUserId;
  final String Function() _platform;
  final Duration submitTimeout;

  static Future<void> _insertIntoSupabase(Map<String, dynamic> row) async {
    await Supabase.instance.client.from(_table).insert(row);
  }

  static String? _sessionUserId() => AuthService.currentUser?.id;

  static String _devicePlatform() =>
      kIsWeb ? 'web' : defaultTargetPlatform.name;

  static String? validateMessage(String? raw) {
    final length = (raw ?? '').trim().runes.length;
    if (length == 0) return 'Please write your feedback.';
    if (length < minMessageLength) {
      return 'Please add a little more detail '
          '(at least $minMessageLength characters).';
    }
    if (length > maxMessageLength) {
      return 'Please keep it to $maxMessageLength characters or fewer.';
    }
    return null;
  }

  bool get isSignedIn => _currentUserId() != null;

  Future<void> submit({
    required FeedbackCategory category,
    required String message,
  }) async {
    final userId = _currentUserId();
    if (userId == null) throw const FeedbackSignInRequiredException();
    final problem = validateMessage(message);
    if (problem != null) throw ArgumentError.value(message, 'message', problem);
    await _insertRow({
      'user_id': userId,
      'category': category.storageValue,
      'message': message.trim(),
      'platform': _platform(),
    }).timeout(submitTimeout);
  }
}
