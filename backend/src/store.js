export class NoticeStore {
  #notices = new Map();
  #now;

  constructor({ now = () => new Date().toISOString() } = {}) {
    this.#now = now;
  }

  saveBoard(boardCode, notices, { success = true } = {}) {
    if (!success) throw new Error('Scrape failed');

    const seen = new Set();
    let newCount = 0;
    for (const notice of notices) {
      const key = `${boardCode}:${notice.sourceIdx}`;
      seen.add(key);
      const previous = this.#notices.get(key);
      this.#notices.set(key, this.#storedNotice(key, previous, notice));
      if (!previous) newCount += 1;
    }

    this.#markMissingPinned(boardCode, seen);
    return { newCount };
  }

  #storedNotice(key, previous, notice) {
    if (previous) {
      if (notice.isNotice && previous.importanceStatus === 'failed') {
        return { ...previous, importanceStatus: 'true' };
      }
      return previous;
    }
    return {
      ...notice,
      id: key,
      importanceStatus: notice.isNotice ? 'true' : null,
      firstCollectedAt: this.#now(),
      lastSeenAt: this.#now(),
    };
  }

  #markMissingPinned(boardCode, seen) {
    for (const [key, notice] of this.#notices) {
      if (
        notice.boardCode === boardCode &&
        notice.isNotice &&
        notice.importanceStatus === 'true' &&
        !seen.has(key)
      ) {
        this.#notices.set(key, { ...notice, importanceStatus: 'failed' });
      }
    }
  }

  get(boardCode, sourceIdx) {
    return this.#notices.get(`${boardCode}:${sourceIdx}`) ?? null;
  }

  list({ boardCode, limit = 20 } = {}) {
    return [...this.#notices.values()]
      .filter((notice) => !boardCode || notice.boardCode === boardCode)
      .sort((a, b) => {
        if (a.isNotice !== b.isNotice) return a.isNotice ? -1 : 1;
        return b.publishedAt.localeCompare(a.publishedAt);
      })
      .slice(0, Math.min(limit, 100));
  }
}
