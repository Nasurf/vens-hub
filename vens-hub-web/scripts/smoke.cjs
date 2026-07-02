const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
  const errors = [];

  page.on('pageerror', (error) => errors.push(`pageerror: ${error.message}`));
  page.on('console', (message) => {
    const text = message.text();
    const expectedFallbackMiss = text.includes('Failed to load resource') && text.includes('status of 405');
    if (message.type() === 'error' && !expectedFallbackMiss) errors.push(`console: ${text}`);
  });

  await page.goto('http://127.0.0.1:5173/register', { waitUntil: 'networkidle' });
  await page.evaluate(() => localStorage.clear());
  await page.reload({ waitUntil: 'networkidle' });

  await page.getByLabel('First name').fill('Ada');
  await page.getByLabel('Last name').fill('Lovelace');
  await page.getByRole('button', { name: 'Continue' }).click();
  await page.getByRole('button', { name: '400 Level' }).click();
  await page.getByRole('button', { name: 'Continue' }).click();
  await page.getByRole('button', { name: 'ELECTRICAL AND ELECTRONICS ENGINEERING' }).click();
  await page.getByRole('button', { name: 'Continue' }).click();
  await page.getByLabel('Email').fill('ada@example.com');
  await page.getByLabel('Create password').fill('secret1');
  await page.getByLabel('Confirm password').fill('secret1');
  await page.getByRole('button', { name: 'Create Account' }).click();
  await page.waitForURL('**/app', { timeout: 10000 });
  await page.getByText('Welcome, Ada').waitFor({ timeout: 15000 });

  await page.getByRole('button', { name: /AI Assistant/i }).click();
  await page.getByLabel('Ask the AI assistant').fill('Explain lift in one sentence.');
  await page.locator('.assistant-input button').click();
  await page.getByText(/assistant shell is working|study prompt|lift/i).waitFor({ timeout: 15000 });
  await page.locator('.assistant-actions button').last().click();

  await page.goto('http://127.0.0.1:5173/app/study', { waitUntil: 'networkidle' });
  await page.locator('input[type="file"]').setInputFiles({
    name: 'aero-note.pdf',
    mimeType: 'application/pdf',
    buffer: Buffer.from('%PDF-1.4\nVens Hub smoke test\n%%EOF'),
  });
  await page.locator('.file-list strong', { hasText: 'aero-note.pdf' }).waitFor({ timeout: 15000 });
  await page.getByText(/Pending Worker\/R2|Uploaded to R2/).waitFor({ timeout: 15000 });

  await page.goto('http://127.0.0.1:5173/app/courses', { waitUntil: 'networkidle' });
  await page.getByPlaceholder('Search by code, title or topic').fill('AAE 101');
  await page.getByText('INTRODUCTION TO AEROSPACE ENGINEERING').waitFor({ timeout: 15000 });
  await page.getByText('INTRODUCTION TO AEROSPACE ENGINEERING').click();
  await page.waitForURL('**/app/courses/AAE%20101');

  await page.getByRole('link', { name: /Multiple choice/i }).click();
  await page.waitForURL('**/app/quiz/AAE%20101?mode=mcq');
  await page.getByText(/multiple choice/i).waitFor({ timeout: 15000 });
  await page.locator('.answers-list button').first().click();
  await page.getByRole('button', { name: /Next question|Finish quiz/i }).click();

  await page.goto('http://127.0.0.1:5173/app/quiz/AAE%20101?mode=theory', { waitUntil: 'networkidle' });
  await page.getByText(/Theory question 1 of/i).waitFor({ timeout: 15000 });
  await page.locator('textarea').fill('The final answer is obtained by substituting the values into the relevant engineering formula and checking the sign convention.');
  await page.getByRole('button', { name: /Evaluate answer/i }).click();
  await page.getByText(/Good answer|Needs review/).waitFor({ timeout: 15000 });

  await page.goto('http://127.0.0.1:5173/app/quiz/AAE%20101?mode=gap', { waitUntil: 'networkidle' });
  await page.getByText(/Gap 1 of/i).waitFor({ timeout: 15000 });
  await page.locator('.answers-list button').first().click();
  await page.getByRole('button', { name: /Check answer/i }).click();
  await page.locator('.feedback-card strong').waitFor({ timeout: 15000 });

  await browser.close();

  if (errors.length) {
    console.error(errors.join('\n'));
    process.exit(1);
  }

  console.log('Playwright smoke passed: auth, AI assistant, R2 upload fallback, MCQ, theory, and gap-fill flows.');
})();
