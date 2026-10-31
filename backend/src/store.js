export class NoticeStore {
  #notices = new Map();

  saveBoard(boardCode, notices, { success = true } = {}) {
    if (!success) throw new Error('Scrape failed');

    const seen = new Set();
    let newCount = 0;
    for (const notice of notices) {
      const key = `${boardCode}:${notice.sourceIdx}`;
      seen.add(key);
      const previous = this.#notices.get(key);
      this.#notices.set(key, {
        ...notice,
        id: previous?.id ?? key,
        importanceStatus: notice.isNotice ? 'true' : null,
        firstCollectedAt: previous?.firstCollectedAt ?? new Date().toISOString(),
        lastSeenAt: new Date().toISOString(),
      });
      if (!previous) newCount += 1;
    }

    for (const [key, notice] of this.#notices) {
      if (notice.boardCode === boardCode && notice.isNotice && !seen.has(key)) {
        this.#notices.set(key, { ...notice, importanceStatus: 'failed' });
      }
    }
    return { newCount };
  }

  get(boardCode, sourceIdx) {
    return this.#notices.get(`${boardCode}:${sourceIdx}`) ?? null;
  }

  list({ boardCode, limit = 20 } = {}) {
    return [...this.#notices.values()]
      .filter((notice) => !boardCode || notice.boardCode === boardCode)
      .sort((a, b) => b.publishedAt.localeCompare(a.publishedAt))
      .slice(0, Math.min(limit, 100));
  }
}
