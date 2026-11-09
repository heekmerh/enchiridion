"""Customer-facing billing messages, worded once for the website, the app, and email."""

PURCHASE_VERIFIED = "Your Premium subscription is active. Enjoy Enchiridion!"
PAYMENT_PROCESSING = "We're confirming your payment. Premium will activate once verification is complete."
RENEWAL_VERIFIED = "Your Premium subscription has been renewed successfully."
PAYMENT_FAILED = ("We couldn't complete your subscription payment. "
                  "Please review your payment method with your subscription provider.")
CANCELLATION = ("Your subscription won't renew. Your Premium access remains available until your "
                "current paid period ends, subject to your plan terms.")
EXPIRY = "Your Premium subscription has expired. You can continue using your Free account."
EXISTING_SUBSCRIPTION = ("Premium is already active on this account. "
                         "Manage your existing subscription before starting another.")
PRICE_INCLUSION = ("All applicable taxes and Enchiridion processing charges are included. "
                   "The displayed subscription price is what Enchiridion charges you.")
GOOGLE_PLAY_MANAGEMENT = "Your subscription is managed by Google Play. Manage or cancel it through your Google Play account."
WEBSITE_MANAGEMENT = "Your subscription was purchased on the Enchiridion website. Cancel future renewals from your account there."
MANUAL_RENEWAL_TERMS = "One-time payment for a single billing period. It does not renew automatically."
AUTOMATIC_RENEWAL_TERMS = "Renews automatically at the same price each billing period until you cancel. Card payments only."
