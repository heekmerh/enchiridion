export const routes = [
    "/", "/about", "/refer", "/rewards", "/reviews", "/premium", "/privacy", "/terms",
    "/reset-password", "/verify-email", "/unsubscribe", "/unsubscribe?token=fixture",
    "/auth/callback?error_description=Example%20sign-in%20failure",
    "/account/subscription", "/premium/processing", "/premium/processing?reference=fixture",
    "/dashboard", "/admin", "/admin/reviews",
    ...["pediatrics", "internal-medicine", "surgery", "obgyn", "orthopaedics", "dermatology", "radiology", "psychiatry"].map(slug => `/books/${slug}`),
    "/missing-page",
];
