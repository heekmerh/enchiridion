/// Digits in the sign-up confirmation code. Must match Supabase →
/// Authentication → Providers → Email → "Email OTP length" (set to 8 here,
/// default 6) — a mismatch rejects every valid code before it's even sent
/// for verification.
const int kEmailOtpLength = 8;

const String supabaseUrl = 'https://lvyoqnmqdquadkfixduq.supabase.co';

const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
    '.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx2eW9xbm1xZHF1YWRrZml4ZHVxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkyNjQwNjksImV4cCI6MjA5NDg0MDA2OX0'
    '.aAH-CB2zyk4hvjC1NPWTIEBSCJUWpH7CbHRQthYkakI';
