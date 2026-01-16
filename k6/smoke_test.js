import http from 'k6/http';
import { check, fail } from 'k6';

// Smoke test - quick validation that the purchase flow works
export const options = {
  vus: 1,
  iterations: 1,
  thresholds: {
    http_req_failed: ['rate<0.01'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000';
const EVENT_CODE = __ENV.EVENT_CODE || 'GLS_21';

function extractCsrfToken(html) {
  const metaMatch = html.match(/<meta name="csrf-token" content="([^"]+)"/);
  if (metaMatch) {
    return metaMatch[1];
  }
  const inputMatch = html.match(/<input[^>]*name="authenticity_token"[^>]*value="([^"]+)"/);
  if (inputMatch) {
    return inputMatch[1];
  }
  return null;
}

export default function () {
  const email = 'loadtest1@example.com';
  const password = 'password123';

  console.log(`Testing purchase flow for ${email} on event ${EVENT_CODE}`);

  // Step 1: Health check
  const healthCheck = http.get(`${BASE_URL}/up`);
  if (!check(healthCheck, { 'app is healthy': (r) => r.status === 200 })) {
    fail('Application is not healthy');
  }
  console.log('✓ Application health check passed');

  // Step 2: Get sign in page
  const signInPage = http.get(`${BASE_URL}/sign_in`);
  if (!check(signInPage, { 'sign in page loaded': (r) => r.status === 200 })) {
    fail('Failed to load sign in page');
  }
  console.log('✓ Sign in page loaded');

  const csrfToken = extractCsrfToken(signInPage.body);
  if (!csrfToken) {
    fail('Failed to extract CSRF token');
  }
  console.log('✓ CSRF token extracted');

  // Step 3: Sign in
  const loginResponse = http.post(
    `${BASE_URL}/sign_in`,
    {
      email: email,
      password: password,
      authenticity_token: csrfToken,
    },
    {
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      redirects: 5,
    }
  );

  if (!check(loginResponse, {
    'login successful': (r) => r.status === 200 || r.status === 302,
  })) {
    console.error(`Login response: ${loginResponse.status} - ${loginResponse.body.substring(0, 500)}`);
    fail('Failed to login');
  }
  console.log('✓ Login successful');

  // Step 4: Load event page
  const eventPage = http.get(`${BASE_URL}/events/${EVENT_CODE}`);
  if (!check(eventPage, { 'event page loaded': (r) => r.status === 200 })) {
    console.error(`Event page response: ${eventPage.status}`);
    fail('Failed to load event page - check EVENT_CODE is valid');
  }
  console.log('✓ Event page loaded');

  const purchaseCsrfToken = extractCsrfToken(eventPage.body);
  if (!purchaseCsrfToken) {
    fail('Failed to extract CSRF token from event page');
  }

  // Step 5: Make purchase
  const purchaseResponse = http.post(
    `${BASE_URL}/events/${EVENT_CODE}/purchase`,
    {
      quantity: '1',
      authenticity_token: purchaseCsrfToken,
    },
    {
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      redirects: 5,
    }
  );

  if (!check(purchaseResponse, {
    'purchase accepted': (r) => r.status === 200 || r.status === 302,
  })) {
    console.error(`Purchase response: ${purchaseResponse.status} - ${purchaseResponse.body.substring(0, 500)}`);
    fail('Purchase request failed');
  }
  console.log('✓ Purchase request accepted (job enqueued)');

  // Check for confirmation message
  if (purchaseResponse.body.includes('queued') || purchaseResponse.body.includes('confirmation')) {
    console.log('✓ Confirmation message displayed');
  }

  console.log('\n✅ Smoke test PASSED - Purchase flow is working correctly');
}

