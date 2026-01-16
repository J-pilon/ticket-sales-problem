import http from 'k6/http';
import { sleep, check, fail } from 'k6';
import { Rate, Counter } from 'k6/metrics';

// Custom metrics
const purchaseSuccessRate = new Rate('purchase_success_rate');
const jobsEnqueued = new Counter('jobs_enqueued');

// SLO: 70 requests per minute = ~1.17 requests per second
// Test configuration for sustained load matching SLO
export const options = {
  scenarios: {
    sustained_load: {
      executor: 'constant-arrival-rate',
      rate: 70, // 70 iterations per timeUnit
      timeUnit: '1m', // per minute (matches SLO)
      duration: '2m', // Run for 2 minutes
      preAllocatedVUs: 10, // Initial pool of VUs
      maxVUs: 50, // Maximum VUs if needed
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.01'], // Less than 1% failure rate
    http_req_duration: ['p(95)<2000'], // 95th percentile under 2 seconds
    purchase_success_rate: ['rate>0.99'], // 99% success rate for purchases
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000';
const USER_COUNT = parseInt(__ENV.USER_COUNT) || 10;

// Available events from the external ticket booking API
const AVAILABLE_EVENTS = [
  'GLS_21',
  'GLS_22',
  'GLS_23',
  'GLS_24',
  'GLS_25',
];

// Pick a random event code
function getRandomEvent() {
  return AVAILABLE_EVENTS[Math.floor(Math.random() * AVAILABLE_EVENTS.length)];
}

// Get CSRF token from a page response
function extractCsrfToken(html) {
  // Look for the authenticity token in meta tag
  const metaMatch = html.match(/<meta name="csrf-token" content="([^"]+)"/);
  if (metaMatch) {
    return metaMatch[1];
  }

  // Fallback: look in form input
  const inputMatch = html.match(/<input[^>]*name="authenticity_token"[^>]*value="([^"]+)"/);
  if (inputMatch) {
    return inputMatch[1];
  }

  return null;
}

// Store test start time for stats query
let testStartTime;

export function setup() {
  // Verify the application is accessible
  const healthCheck = http.get(`${BASE_URL}/up`);
  if (healthCheck.status !== 200) {
    fail(`Application health check failed: ${healthCheck.status}`);
  }

  console.log(`Performance test starting against ${BASE_URL}`);
  console.log(`Available events: ${AVAILABLE_EVENTS.join(', ')}`);
  console.log(`Using ${USER_COUNT} test users`);

  // Record test start time
  testStartTime = new Date().toISOString();

  return { startTime: testStartTime };
}

export default function () {
  // Assign each virtual user a unique test account (cycling through available users)
  const userNumber = ((__VU - 1) % USER_COUNT) + 1;
  const email = `loadtest${userNumber}@example.com`;
  const password = 'password123';

  // Pick a random event for this iteration
  const eventCode = getRandomEvent();

  // Step 1: Get the sign in page to obtain CSRF token
  const signInPage = http.get(`${BASE_URL}/sign_in`);

  check(signInPage, {
    'sign in page loaded': (r) => r.status === 200,
  });

  const csrfToken = extractCsrfToken(signInPage.body);
  if (!csrfToken) {
    console.error('Failed to extract CSRF token from sign in page');
    purchaseSuccessRate.add(false);
    return;
  }

  // Step 2: Sign in user with form data (Rails standard form submission)
  const loginPayload = {
    email: email,
    password: password,
    authenticity_token: csrfToken,
  };

  const loginParams = {
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    redirects: 5, // Follow redirects after login
  };

  const loginResponse = http.post(
    `${BASE_URL}/sign_in`,
    loginPayload,
    loginParams
  );

  const loginSuccess = check(loginResponse, {
    'login successful': (r) => r.status === 200 || r.status === 302,
    'login redirected to home': (r) => r.url.includes(BASE_URL) && !r.url.includes('sign_in'),
  });

  if (!loginSuccess) {
    console.error(`Login failed for ${email}: status=${loginResponse.status}`);
    purchaseSuccessRate.add(false);
    return;
  }

  // Step 3: Get the event page to obtain a fresh CSRF token for purchase
  const eventPage = http.get(`${BASE_URL}/events/${eventCode}`);

  const eventPageLoaded = check(eventPage, {
    'event page loaded': (r) => r.status === 200,
  });

  if (!eventPageLoaded) {
    console.error(`Failed to load event page: ${eventPage.status}`);
    purchaseSuccessRate.add(false);
    return;
  }

  const purchaseCsrfToken = extractCsrfToken(eventPage.body);
  if (!purchaseCsrfToken) {
    console.error('Failed to extract CSRF token from event page');
    purchaseSuccessRate.add(false);
    return;
  }

  // Step 4: Make purchase request (this enqueues the job)
  const purchasePayload = {
    quantity: '1',
    authenticity_token: purchaseCsrfToken,
  };

  const purchaseParams = {
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    redirects: 5, // Follow redirect after purchase
  };

  const purchaseResponse = http.post(
    `${BASE_URL}/events/${eventCode}/purchase`,
    purchasePayload,
    purchaseParams
  );

  const purchaseSuccess = check(purchaseResponse, {
    'purchase request accepted': (r) => r.status === 200 || r.status === 302,
    'redirected to event page': (r) => r.url.includes(`/events/${eventCode}`),
    'shows queue confirmation': (r) =>
      r.body && r.body.includes('queued') || r.body.includes('confirmation'),
  });

  purchaseSuccessRate.add(purchaseSuccess);

  if (purchaseSuccess) {
    jobsEnqueued.add(1);
  } else {
    console.error(`Purchase failed: status=${purchaseResponse.status}, url=${purchaseResponse.url}`);
  }

  // Step 5: Sign out to clean up session
  const signOutCsrfToken = extractCsrfToken(purchaseResponse.body);
  if (signOutCsrfToken) {
    const logoutResponse = http.post(
      `${BASE_URL}/sign_out`,
      {
        _method: 'delete',
        authenticity_token: signOutCsrfToken,
      },
      {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        redirects: 5,
      }
    );

    check(logoutResponse, {
      'logout successful': (r) => r.status === 200 || r.status === 302,
    });
  }

  // Small delay between iterations
  sleep(0.5);
}

export function teardown(data) {
  console.log('\n========================================');
  console.log('Performance test completed');
  console.log('Waiting for background jobs to complete...');
  console.log('========================================\n');

  // Wait a bit for jobs to start processing
  sleep(5);

  // Poll for job completion stats (10 attempts × 5 seconds = 50 seconds max)
  const maxAttempts = 10;
  let attempts = 0;

  while (attempts < maxAttempts) {
    const statsResponse = http.get(`${BASE_URL}/api/purchase_stats?since=${data.startTime}`);

    if (statsResponse.status === 200) {
      const result = JSON.parse(statsResponse.body);
      const stats = result.stats;

      console.log(`📊 Job Status (attempt ${attempts + 1}/${maxAttempts}):`);
      console.log(`   Total Jobs:    ${stats.total}`);
      console.log(`   Pending:       ${stats.pending}`);
      console.log(`   Completed:     ${stats.completed}`);
      console.log(`   Failed:        ${stats.failed}`);
      console.log(`   API Success:   ${stats.api_success}`);
      console.log(`   Emails Sent:   ${stats.email_sent}`);
      console.log('');

      if (stats.pending === 0 && stats.total > 0) {
        console.log('========================================');
        console.log('✅ ALL JOBS COMPLETED!');
        console.log('========================================');
        console.log('');
        console.log('📈 Final Results:');
        console.log(`   Total Purchases:      ${stats.total}`);
        console.log(`   Job Success Rate:     ${((stats.completed / stats.total) * 100).toFixed(1)}%`);
        console.log(`   API Success Rate:     ${((stats.api_success / stats.total) * 100).toFixed(1)}%`);
        console.log(`   Email Delivery Rate:  ${((stats.email_sent / stats.total) * 100).toFixed(1)}%`);
        console.log(`   Failed Jobs:          ${stats.failed}`);
        console.log('');
        return;
      }
    } else {
      console.log(`⚠️  Failed to get stats: ${statsResponse.status}`);
    }

    attempts++;
    sleep(5);
  }

  // Print final stats even if jobs didn't complete
  const finalStats = http.get(`${BASE_URL}/api/purchase_stats?since=${data.startTime}`);
  if (finalStats.status === 200) {
    const stats = JSON.parse(finalStats.body).stats;
    console.log('========================================');
    console.log('⚠️  TIMEOUT: Some jobs still pending');
    console.log('========================================');
    console.log(`   Completed: ${stats.completed}/${stats.total} (${((stats.completed / stats.total) * 100).toFixed(1)}%)`);
    console.log(`   Pending:   ${stats.pending}`);
    console.log(`   Failed:    ${stats.failed}`);
  }
}
