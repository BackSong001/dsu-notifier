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

## 테스트·운영 환경 분리

테스트 Android 빌드는 다음 테스트 설정을 사용한다.

- Firebase: `frontend/android/app/src/debug/google-services.json`
- Supabase URL·anon key 및 외부 테스트 키: 저장소 루트의 `.env.local`
- Supabase 데이터베이스와 Edge Function: 테스트용 Supabase 프로젝트

테스트 APK는 `.env.local`의 값을 빌드 변수로 전달한다.

```bash
cd frontend
source ../.env.local
flutter build apk --debug \
  --dart-define=SUPABASE_FUNCTIONS_URL="$SUPABASE_URL/functions/v1" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
```

운영 빌드는 다음 운영 설정을 사용한다.

- Firebase: `frontend/android/app/src/release/google-services.json`
- Supabase URL·anon key: 운영 프로젝트 값
- Supabase Secrets와 Cron: 운영 프로젝트 값

`.env`, `.env.local`, `google-services.json`은 Git에 커밋하지 않는다. 테스트 디바이스·공지·FCM 토큰도 운영 프로젝트로 복사하지 않는다.
