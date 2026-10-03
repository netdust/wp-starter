import { defineConfig } from '@playwright/test';

/**
 * E2E tier config (T11). Runs HOST-side against the live DDEV URL.
 *
 * WP_BASE_URL is derived by bin/e2e.sh — never hardcoded here (SC-5).
 * Fail loudly if invoked without it. Playwright defaults (no retries,
 * list reporter, single chromium project) are NOT restated (review C4).
 */
const baseURL = process.env.WP_BASE_URL;
if (!baseURL) {
  throw new Error(
    'WP_BASE_URL is not set. Run the suite via `composer test:e2e` or `ddev test-e2e` '
    + '(bin/e2e.sh derives the URL) — there is deliberately no hardcoded fallback.',
  );
}

// A remote run (make e2e env=<env>) shares one server and reaches WP-CLI over
// SSH: fewer workers and a longer budget, or slow endpoints time out under load.
const remote = Boolean(process.env.E2E_ENV) && process.env.E2E_ENV !== 'local';

export default defineConfig({
  testDir: './tests/E2E',
  ...(remote ? { workers: Number(process.env.E2E_WORKERS) || 3, timeout: 60_000 } : {}),
  use: {
    baseURL,
    // mkcert's root CA is machine-local; config-level tolerance keeps this
    // template portable across machines instead of coupling to a CA path.
    ignoreHTTPSErrors: true,
  },
});
