# Testing Strategies

This document describes the testing frameworks, current test coverage, and execution instructions for the Enchiridion application.

## 1. Backend Testing (Python)

### Frameworks & Tools
- **Test Runner:** `pytest` is the primary testing framework.
- **Asynchronous Testing:** The `anyio` plugin (`@pytest.mark.anyio`) is used to test asynchronous API endpoints.
- **HTTP Client:** `httpx` along with `ASGITransport` is utilized to send test requests directly against the FastAPI application without needing to spin up a live server.

### Test Coverage
- **Location:** Tests are located in the `backend/tests/` directory.
- **Current Coverage:** 
  - `test_api.py` includes basic integration tests for core API endpoints.
  - Endpoints covered include root health check (`/`), user registration (`/auth/register`), reviews submission (`/reviews/`), and distributor lead submission (`/referral/distributor-lead`).
  - *Note:* The tests are currently aware of external dependencies (like Google Sheets), asserting for multiple potential response codes (e.g., `[200, 500]`) to account for CI environments lacking appropriate mock credentials. Future test improvements should include robust mocking (e.g., using `unittest.mock`) for external clients like `sheets_client`.

### How to Run Tests
To run the backend tests, navigate to the `backend` directory and execute `pytest`:

```bash
cd backend
pytest tests/
```

## 2. Frontend Testing (Next.js)

### Frameworks & Tools
- **Static Analysis:** At present, the primary verification tool is ESLint (`eslint`, `eslint-config-next`) alongside TypeScript compiler checks.
- **Automated Testing:** There are currently no explicit automated testing frameworks (like Jest, Vitest, React Testing Library, or Cypress) configured in the frontend `package.json`.
- **Test Coverage:** Currently 0% automated test coverage. There are no `*.test.tsx` or `*.spec.tsx` files.

### How to Run Verification
To ensure the frontend code follows best practices and catches static errors, run the lint command:

```bash
cd frontend
npm run lint
```
*(To introduce frontend tests in the future, it is recommended to install and configure Vitest and React Testing Library)*.
