# External Integrations

## Databases & Storage
*   **Google Sheets API (`gspread`)**: Serves as the primary database for the application, handling user data, referral milestones, audit logs, and analytics. It is authenticated via Google Service Account credentials.

## Third-Party APIs & Services
*   **Paystack**: Integrated for payment processing. The backend exposes webhook endpoints (`/referral/paystack/webhook` and `/paystack/webhook`) validated securely via HMAC signatures to process purchase completions, credit referral milestones, and manage cashbacks.
*   **SMTP Email (FastAPI Mail)**: Configured to send system emails such as user notifications, distributor lead reports, and password resets. The environment setup suggests usage with standard SMTP providers (like Gmail).
*   **IPify API**: Used on the frontend to retrieve the user's IP address (`https://api.ipify.org?format=json`) for logging referral activity, tracking unique visitors, and capturing lead analytics.
