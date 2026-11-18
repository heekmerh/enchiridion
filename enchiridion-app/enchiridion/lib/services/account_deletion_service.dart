import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/backend_config.dart';
import 'access_service.dart';
import 'auth_service.dart';

enum AccountDeletionOutcome { deleted, cancelGooglePlayFirst, refused, failed }

class AccountDeletionResult {
  final AccountDeletionOutcome outcome;
  final String message;
  final String? manageUrl;

  const AccountDeletionResult(this.outcome, this.message, {this.manageUrl});

  bool get isDeleted => outcome == AccountDeletionOutcome.deleted;
}

const String kAccountDeletionFailed =
    "We couldn't delete your account just now. Check your connection and try again.";
const String kAccountDeleted = 'Your account and its data have been deleted.';

AccountDeletionResult accountDeletionResultFrom(http.Response response) {
  if (response.statusCode == 200) {
    return const AccountDeletionResult(
        AccountDeletionOutcome.deleted, kAccountDeleted);
  }
  Object? detail;
  try {
    detail = (jsonDecode(response.body) as Map<String, dynamic>)['detail'];
  } catch (_) {
    detail = null;
  }
  if (response.statusCode == 409 && detail is Map) {
    final message = detail['message'] as String? ?? kAccountDeletionFailed;
    if (detail['code'] == 'cancel_google_play_first') {
      return AccountDeletionResult(
        AccountDeletionOutcome.cancelGooglePlayFirst,
        message,
        manageUrl: detail['url'] as String? ?? kGooglePlaySubscriptionsUrl,
      );
    }
    return AccountDeletionResult(AccountDeletionOutcome.refused, message);
  }
  return const AccountDeletionResult(
      AccountDeletionOutcome.failed, kAccountDeletionFailed);
}

class AccountDeletionService {
  static final AccountDeletionService instance =
      AccountDeletionService(http.Client());

  static const Duration _timeout = Duration(seconds: 30);
  static const List<String> _userFileBuckets = ['avatars', 'notebook-images'];

  final http.Client _client;

  AccountDeletionService(this._client);

  Future<AccountDeletionResult> deleteMyAccount() async {
    final user = AuthService.currentUser;
    final accessToken = AuthService.currentSession?.accessToken;
    if (user == null || accessToken == null) {
      return const AccountDeletionResult(
          AccountDeletionOutcome.failed, kAccountDeletionFailed);
    }
    await _removeOwnFiles(user.id);
    final AccountDeletionResult result;
    try {
      final response = await _client.delete(
        Uri.parse('$kBackendBaseUrl/api/v1/account'),
        headers: {'Authorization': 'Bearer $accessToken'},
      ).timeout(_timeout);
      result = accountDeletionResultFrom(response);
    } catch (_) {
      return const AccountDeletionResult(
          AccountDeletionOutcome.failed, kAccountDeletionFailed);
    }
    if (result.isDeleted) await _signOutLocally();
    return result;
  }

  Future<void> _removeOwnFiles(String userId) async {
    final storage = Supabase.instance.client.storage;
    for (final bucket in _userFileBuckets) {
      try {
        final files = await storage.from(bucket).list(path: userId);
        final paths = [for (final file in files) '$userId/${file.name}'];
        if (paths.isNotEmpty) await storage.from(bucket).remove(paths);
      } catch (_) {}
    }
  }

  Future<void> _signOutLocally() async {
    AccessService.instance.clearCache();
    try {
      await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    } catch (_) {}
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }
}
