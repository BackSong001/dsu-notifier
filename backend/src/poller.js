export function createPoller({ intervalMs = 600_000, scrape }) {
  let latest = [];
  return {
    intervalMs,
    get latest() {
      return latest;
    },
    async runOnce() {
      latest = await scrape();
      return latest;
    },
    start() {
      return setInterval(() => void this.runOnce(), intervalMs);
    },
  };
}
