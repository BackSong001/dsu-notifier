const normalNotice = {
  boardCode: 'MN2000194',
  boardName: '학사',
  sourceIdx: '1',
  number: 1,
  title: '일반 공지',
  author: '처',
  publishedAt: '2026-10-29',
  viewCount: 1,
  url: 'https://www.dongseo.ac.kr/kr/index.php?pCode=MN2000194&idx=1',
  isNotice: false,
  importanceStatus: null,
};

export function makeNotice(overrides = {}) {
  return { ...normalNotice, ...overrides };
}

export const pinnedNotice = makeNotice({
  sourceIdx: '2',
  number: null,
  title: '고정 공지',
  isNotice: true,
  importanceStatus: 'true',
});
