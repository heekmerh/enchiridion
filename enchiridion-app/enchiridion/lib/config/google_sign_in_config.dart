// The Web OAuth client ID from Google Cloud (not the Android one); Google Sign-In stays hidden until it is set.
const String kGoogleWebClientId =
    String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

bool get isGoogleSignInConfigured => kGoogleWebClientId.isNotEmpty;
