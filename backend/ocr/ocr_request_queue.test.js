const assert = require('assert');
const { OcrRequestQueue } = require('./ocr_request_queue');

async function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function testSerializesConcurrentJobs() {
  const queue = new OcrRequestQueue({ maxConcurrent: 1, maxQueue: 10 });
  let running = 0;
  let maxRunning = 0;

  const job = async () => {
    running += 1;
    maxRunning = Math.max(maxRunning, running);
    await sleep(30);
    running -= 1;
    return 'ok';
  };

  await Promise.all([queue.run(job), queue.run(job), queue.run(job)]);
  assert.strictEqual(maxRunning, 1);
}

async function testRejectsWhenQueueFull() {
  const queue = new OcrRequestQueue({ maxConcurrent: 1, maxQueue: 1, queueTimeoutMs: 5000 });
  let release;
  const blocker = new Promise((resolve) => {
    release = resolve;
  });

  const first = queue.run(async () => {
    await blocker;
    return 1;
  });
  const second = queue.run(async () => 2);

  let rejected = false;
  try {
    await queue.run(async () => 3);
  } catch (error) {
    rejected = true;
    assert.strictEqual(error.code, 'OCR_OVERLOADED');
    assert.strictEqual(error.status, 503);
  }

  assert.ok(rejected);
  release();
  await Promise.all([first, second]);
}

async function run() {
  await testSerializesConcurrentJobs();
  console.log('OK testSerializesConcurrentJobs');
  await testRejectsWhenQueueFull();
  console.log('OK testRejectsWhenQueueFull');
  console.log('\n2/2 OCR queue tests passed');
}

run().catch((error) => {
  console.error(error);
  process.exit(1);
});
