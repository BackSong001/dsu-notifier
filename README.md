# dsu-notifier

## Backend tests

```bash
npm test
```

테스트는 `backend/__TEST__/`에 있으며 Node 내장 test runner로 실행한다. 운영 수집 주기는 10분이고, 테스트 환경의 Cron 수집 주기는 1분이다.

Supabase 스키마는 `supabase/migrations/`에 있다. 로컬 Supabase를 실행할 수 있는 Docker 환경에서는 다음 명령으로 적용한다.

```bash
npx supabase start
npx supabase db reset
```
