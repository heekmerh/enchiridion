/// Digits in the sign-up confirmation code.
///
/// MUST match Supabase → Authentication → Sign In / Providers → Email →
/// "Email OTP length". Supabase allows 6–10 and defaults to 6; this project
/// is set to 8. If the two disagree the confirm screen rejects every valid
/// code, because it validates the length before sending it to be verified.
const int kEmailOtpLength = 8;

const String supabaseUrl = 'https://lvyoqnmqdquadkfixduq.supabase.co';

const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
    '.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx2eW9xbm1xZHF1YWRrZml4ZHVxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkyNjQwNjksImV4cCI6MjA5NDg0MDA2OX0'
    '.aAH-CB2zyk4hvjC1NPWTIEBSCJUWpH7CbHRQthYkakI';
