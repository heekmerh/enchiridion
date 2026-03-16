# Codebase Concerns & Technical Debt

## 1. Architectural & Scalability Flaws
- **Google Sheets as Primary Database:** The backend (`backend/app/auth.py`, `backend/app/sheets.py`) relies entirely on Google Sheets for user management, authentication, referrals, and logging. This is a critical architectural flaw because:
  - **Performance:** Methods like `get_by_email` fetch the entire sheet into memory using `sheets_client.get_all_records` to search for a single user, resulting in O(N) complexity for every login or lookup.
  - **API Rate Limiting:** The Google Sheets API has strict read/write rate limits. Moderate concurrent traffic will quickly trigger `429 Too Many Requests` errors, leading to application downtime.
  - **Concurrency & Transactions:** There is no row-level locking or ACID compliance. Simultaneous sign-ups or profile updates will inevitably lead to race conditions, data overwrites, and corrupted rows.

## 2. Security Vulnerabilities
- **Insecure Token Storage (XSS Risk):** The frontend stores JWT access tokens in `localStorage` (e.g., `localStorage.setItem("enchiridion_token", ...)` in `PartnerLoginModal.tsx` and multiple other components). This exposes user sessions to Cross-Site Scripting (XSS) attacks. Authentication should migrate to secure, `HttpOnly` cookies.
- **Weak Cryptographic Fallbacks:** In `backend/app/auth.py`, the authentication secret defaults to a predictable, hardcoded string (`SECRET = os.getenv("AUTH_SECRET", "SECRET")`). If deployed without properly configuring the environment, attackers can easily forge valid JWTs and hijack accounts.
- **Flawed Fraud Prevention:** The IP-based fraud check for referrals (`referrer_ip == referee_ip`) will falsely flag and block legitimate users sharing the same NAT or network infrastructure (e.g., medical students using university campus Wi-Fi or hospital networks).

## 3. Code Quality & Technical Debt
- **Fragile Data Manipulation:** Database interactions depend heavily on hardcoded column indices and rigid offsets (e.g., `sheets_client.update_cell("Partners", row_idx, 2, ...)`). Any modification to the Google Sheet structure (like adding or rearranging columns) will instantly break core backend logic.
- **Lack of Data Integrity Constraints:** Without a relational database system (RDBMS) like PostgreSQL, there are no structural guarantees for unique constraints (e.g., ensuring emails are strictly unique at the schema level), foreign keys, or data normalization.
- **Scattered State Management:** The frontend continuously calls `localStorage.getItem("enchiridion_token")` directly within React components. This avoids a unified Authentication Context or Next.js middleware, which can lead to hydration mismatches during Server-Side Rendering (SSR), redundant code, and inconsistent UI states across different views.