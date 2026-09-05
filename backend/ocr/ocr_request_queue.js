const { logOcr } = require('./ocr_logging');
const { ocrMaxConcurrentDefault, isLowMemoryOcr } = require('./low_memory');

/**
 * Limits concurrent full-document OCR jobs so bursts queue
 * instead of overloading Paddle/Tesseract and blowing RAM.
 */
class OcrRequestQueue {
  constructor(options = {}) {
    this.maxConcurrent = Number(
      options.maxConcurrent ??
        process.env.OCR_MAX_CONCURRENT_REQUESTS ??
        ocrMaxConcurrentDefault(),
    );
    this.maxQueue = Number(options.maxQueue ?? process.env.OCR_MAX_QUEUE_SIZE ?? 1000);
    this.queueTimeoutMs = Number(
      options.queueTimeoutMs ?? process.env.OCR_QUEUE_TIMEOUT_MS ?? 300000,
    );
    this.active = 0;
    this.queue = [];
    this.completed = 0;
    this.rejected = 0;
  }

  stats() {
    return {
      active: this.active,
      queued: this.queue.length,
      maxConcurrent: this.maxConcurrent,
      maxQueue: this.maxQueue,
      completed: this.completed,
      rejected: this.rejected,
    };
  }

  async run(taskFn) {
    if (this.queue.length >= this.maxQueue) {
      this.rejected += 1;
      const err = new Error(
        'OCR service is busy due to high demand. Please wait a moment and try again.',
      );
      err.code = 'OCR_OVERLOADED';
      err.status = 503;
      err.retryAfterSeconds = Number(process.env.OCR_RETRY_AFTER_SECONDS || 15);
      throw err;
    }

    return new Promise((resolve, reject) => {
      this.queue.push({
        taskFn,
        resolve,
        reject,
        enqueuedAt: Date.now(),
      });
      this._pump();
    });
  }

  _pump() {
    while (this.active < this.maxConcurrent && this.queue.length > 0) {
      const entry = this.queue.shift();
      const waitedMs = Date.now() - entry.enqueuedAt;
      if (waitedMs > this.queueTimeoutMs) {
        this.rejected += 1;
        const err = new Error('OCR request timed out while waiting in queue.');
        err.code = 'OCR_QUEUE_TIMEOUT';
        err.status = 503;
        err.retryAfterSeconds = Number(process.env.OCR_RETRY_AFTER_SECONDS || 15);
        entry.reject(err);
        continue;
      }

      this.active += 1;
      if (waitedMs >= 2000) {
        logOcr('ocr_queue_wait', {
          waitedMs,
          active: this.active,
          queued: this.queue.length,
        });
      }

      Promise.resolve()
        .then(() => entry.taskFn())
        .then((result) => {
          this.completed += 1;
          entry.resolve(result);
        })
        .catch(entry.reject)
        .finally(async () => {
          // Free Tesseract WASM workers after each job on small hosts.
          if (isLowMemoryOcr()) {
            try {
              const { terminateWorkers } = require('./tesseract_engine');
              await terminateWorkers();
            } catch (_) {
              // ignore
            }
            if (typeof global.gc === 'function') {
              try {
                global.gc();
              } catch (_) {}
            }
          }
          this.active = Math.max(0, this.active - 1);
          this._pump();
        });
    }
  }
}

const globalOcrQueue = new OcrRequestQueue();

function runQueuedOcr(taskFn) {
  return globalOcrQueue.run(taskFn);
}

function getOcrQueueStats() {
  return globalOcrQueue.stats();
}

module.exports = {
  OcrRequestQueue,
  runQueuedOcr,
  getOcrQueueStats,
};
