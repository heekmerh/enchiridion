/// Flutterwave's PUBLIC key — like [supabaseAnonKey] in supabase_config.dart,
/// this is meant to ship inside the client. It can only initiate a checkout,
/// never move money or confirm one on its own; the SECRET key that actually
/// verifies a transaction lives only in the verify-flutterwave-payment
/// Supabase Edge Function's environment, never in this app.
///
/// This is a placeholder — every checkout attempt will fail until it's
/// replaced with the real key from the Flutterwave dashboard (Settings →
/// API Keys). Use the TEST public key while [flutterwaveIsTestMode] is true.
const String flutterwavePublicKey = 'FLWPUBK_TEST-REPLACE_ME-X';

/// Flip to false once real (live) keys are in place on both this constant
/// and the Edge Function's FLUTTERWAVE_SECRET_KEY secret.
const bool flutterwaveIsTestMode = true;

const String flutterwaveCurrency = 'NGN';

/// Where Flutterwave's in-app checkout browser redirects on completion.
/// Never actually loaded — the package intercepts navigation to it and
/// reads the status/tx_ref/transaction_id query params off the URL, so this
/// only needs to be a syntactically valid URL, not a real reachable page.
const String flutterwaveRedirectUrl = 'https://enchiridion.app/payment-complete';
