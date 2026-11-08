# Android 출시와 Supabase 배포

## 배포 전제

운영 대상은 사용자 소유의 DSU 전용 Supabase·Firebase 프로젝트다. `.env.local`과 debug Firebase는 테스트용이며 운영으로 복사하지 않는다. 현재 CLI에 표시되는 다른 앱 프로젝트를 배포 대상으로 사용하면 안 된다.

운영 공개는 아직 완료되지 않았다. 아래 절차에는 운영 프로젝트 접근 권한, release Firebase 설정, Android 서명 키가 필요하다. 개인 APK 배포와 Play Store 공개 중 최종 방식도 확정해야 한다.

이 버전은 로그인 없이 설치 UUID와 별도 비밀값으로 디바이스를 인증한다. 구버전 앱의 인증 없는 디바이스 API 요청은 401이 된다. 개인 기기의 앱 업데이트와 아래 데이터 이전을 같은 배포 작업으로 진행한다.

## 설정

1. `.env.production.example`을 `.env.production`으로 복사하고 운영 값만 넣는다. FCM 비밀키는 따옴표로 감싼 한 줄의 `\n` 이스케이프 형식으로 보관한다. Cron secret 두 개는 각각 무작위 32바이트 이상으로 생성한다.
2. 운영 Firebase의 Android 앱 ID는 `com.dsu.notifier`다. 설정 파일은 `frontend/android/app/src/release/google-services.json`에 둔다.
3. `frontend/android/key.properties.example`을 `key.properties`로 복사하고 별도 보관하는 릴리스 keystore 경로·암호를 넣는다. 서명 키는 백업한다. 같은 앱을 업데이트하려면 같은 키가 필요하다.
4. Supabase CLI로 DSU 운영 프로젝트에 접근할 수 있는지 확인한다. 비밀값과 JSON 설정·서명 키는 Git에 넣지 않는다.

## 검증

```bash
npm ci
npm test
npx --yes deno test --allow-read --no-lock backend/__TEST__/edge
npx --yes deno check --node-modules-dir=auto --no-lock supabase/functions/*/index.ts
npm run test:db
cd frontend
flutter test
flutter analyze
```

`test:db`는 Docker의 임시 DB에 모든 migration을 적용해 RLS/RPC 권한, 공지와 outbox의 원자성, 고정 상태 전이와 동시 발송 claim을 검증하고 컨테이너를 삭제한다. 외부 사이트 테스트는 별도로 실행한다.

```bash
npx --yes deno test --allow-net --no-lock backend/__TEST__/integration/live_test.ts
```

실제 Edge API 테스트는 데이터가 없는 별도 로컬 Supabase에서만 실행한다. `DSU_TEST_URL`, `DSU_TEST_ANON_KEY`, `DSU_TEST_SERVICE_KEY`를 로컬 환경에 넣고 다음을 실행한다. 테스트는 자신이 생성한 행을 정리하며 localhost 이외 대상을 거부한다.

```bash
node --test backend/__TEST__/integration/edge.test.js
```

## 백엔드 배포 순서

아래 `<DSU_PROJECT_REF>`는 운영 URL에서 확인한 프로젝트 ID다. 프로젝트 목록과 URL을 대조한 후 실행한다. `db reset`은 운영에서 실행하지 않는다. 이미 있는 migration 이력이 다르면 중단하고 이력을 먼저 확인하며 임의 repair로 덮지 않는다.

기존 배포가 있는 경우 **DB/Edge 교체 전에** DSU의 기존 수집·발송 Cron을 먼저 중지한다. SQL Editor에서 대상 job의 ID·이름·스케줄만 확인하고 운영자가 확인한 DSU jobid만 unschedule한다. command 전체에는 기존 비밀값이 있을 수 있으므로 출력하거나 문서에 복사하지 않는다.

```sql
select jobid, jobname, schedule from cron.job
where command like '%/scrape-notices%' or command like '%/dispatch-notifications%';
-- 확인한 DSU 작업에 대해서만 실행한다.
-- select cron.unschedule(<DSU_JOB_ID>);
```

이미 `pg_net`에 큐잉된 HTTP 요청과 실행 중인 구버전 Edge Function이 모두 끝났는지 확인한 뒤 진행한다. Cron 중지만으로 이미 시작된 발송이 종료되지는 않는다. Supabase Edge 실행 이력/로그에서 진행 중 요청이 없는지 확인하고, 종료를 확인할 수 없으면 마이그레이션과 관리자 이전을 시작하지 않는다. 이 순서는 구 발송기가 읽어 둔 pending을 새 발송기가 다시 보내는 것을 막는다.

```bash
npx supabase projects list
npx supabase link --project-ref <DSU_PROJECT_REF>
npx supabase db push --dry-run
npx supabase db push
```

FCM 3개 값과 `SCRAPE_CRON_SECRET`, `DISPATCH_CRON_SECRET`만 운영 Supabase Secrets에 등록한다. URL과 service role은 Supabase가 제공하는 내장 환경값을 쓴다. 전체 `.env.production`을 Secrets에 업로드하지 않는다.

```bash
npx supabase functions deploy notices --project-ref <DSU_PROJECT_REF>
npx supabase functions deploy devices --project-ref <DSU_PROJECT_REF>
npx supabase functions deploy scrape-notices --project-ref <DSU_PROJECT_REF>
npx supabase functions deploy dispatch-notifications --project-ref <DSU_PROJECT_REF>
```

Supabase Dashboard의 Vault에 다음 이름을 등록한다. 값은 로컬 `.env.production`과 같은 운영 값으로 입력한다.

| Vault 이름 | 값 |
|---|---|
| `dsu_functions_url` | 운영 Supabase URL + `/functions/v1` |
| `dsu_scrape_cron_secret` | 운영 `SCRAPE_CRON_SECRET` |
| `dsu_dispatch_cron_secret` | 운영 `DISPATCH_CRON_SECRET` |

처음 수집은 구독을 켜기 전에 실행하면 기존 공지가 대량 푸시되지 않는다. 운영 내부 함수는 `x-cron-secret`으로 호출한다. 비밀값을 명령 인수나 로그로 출력하지 않는다.

앱 업데이트와 아래 구버전 관리자 데이터 이전을 완료하고, 기존 DSU 작업이 중지된 상태인지 다시 확인한다. 다른 앱의 작업은 수정하지 않는다. **이전 완료 후에만** SQL Editor에서 다음을 실행해 새 Cron을 활성화한다.

```sql
select public.configure_notice_cron();
select jobname, schedule, active from cron.job
where jobname in ('dsu-scrape-notices','dsu-dispatch-notifications');
```

수집은 `*/10 * * * *`, 발송은 `* * * * *` 두 작업이어야 한다. 재실행해도 같은 이름의 작업은 중복 생성되지 않는다. Vault가 없으면 `CRON_SECRETS_NOT_CONFIGURED`로 실패한다. 테스트 수집 1분 주기는 운영에 적용하지 않는다.

등록 후 `cron.job_run_details`, `net._http_response`의 HTTP 상태, `scrape_runs`의 6개 게시판 성공, outbox 결과를 확인한다. Cron SQL 성공만으로 HTTP/FCM 성공을 판단하지 않는다. Cron·Vault 방식은 [Supabase 공식 문서](https://supabase.com/docs/guides/functions/schedule-functions)를 따른다.

## 구버전 설치 데이터 이전

FCM 토큰을 아는 것만으로 다른 설치의 설정을 가져오지 못하도록 자동 이전하지 않는다. 같은 토큰이 다른 활성 ID에 연결돼 있으면 새 등록은 거절된다. 기존 행·저장 상태·발송 이력은 삭제하지 않는다.

관리자가 실제 동일 기기임을 확인한 후 다음 순서로 이전한다.

1. 기존 ID와 설정·발송 이력을 별도 안전한 경로로 백업한다. 구버전 ID 자체가 FCM 토큰이므로 로그·문서에 남기지 않는다.
2. 해당 기존 기기의 `active`만 false로 바꾸고 새 앱에서 `다시 연결`한다.
3. 새 UUID와 비밀값 해시가 있는 등록 행, 같은 기기의 FCM 토큰을 확인한다.
4. 아래 트랜잭션의 두 자리표시자를 실제 ID로 바꿔 관리자 전용 SQL 연결에서 실행한다. 비밀값을 일반 로그로 남기지 않는다.

```sql
begin;
-- 동일 기기 확인을 마친 관리자만 실행한다.
insert into public.notification_preferences(device_id,board_code,enabled)
select '<NEW_INSTALLATION_UUID>',board_code,enabled from public.notification_preferences
where device_id='<LEGACY_DEVICE_ID>' on conflict do nothing;
insert into public.notice_alarm_preferences(device_id,notice_id,enabled)
select '<NEW_INSTALLATION_UUID>',notice_id,enabled from public.notice_alarm_preferences
where device_id='<LEGACY_DEVICE_ID>' on conflict do nothing;
-- 명확히 미발송인 pending만 이전한다. sent/sending/결과 불명은 재전송하지 않는다.
insert into public.notification_outbox(notice_id,device_id,status,attempts,next_attempt_at)
select notice_id,'<NEW_INSTALLATION_UUID>','pending',attempts,next_attempt_at
from public.notification_outbox where device_id='<LEGACY_DEVICE_ID>' and status='pending'
on conflict do nothing;
update public.notification_outbox set status='failed',last_error='DEVICE_MIGRATED'
where device_id='<LEGACY_DEVICE_ID>' and status='pending';
commit;
```

앱을 다시 실행해 게시판 설정·오래된 저장 공지를 확인한다. 이 절차 동안 수집된 공지는 앱 목록에서 확인할 수 있다. 기존 설치가 없는 최초 배포에는 이 절차가 필요 없다.

## Android 빌드와 확인

서명·release Firebase 설정이 없으면 릴리스 빌드는 명확한 오류로 실패한다. 디버그 서명을 대신 사용하지 않는다. 공개 URL과 anon/publishable key 두 개만 Dart 빌드에 전달한다.

```bash
set -a
source .env.production
set +a
cd frontend
flutter build apk --release \
  --dart-define=SUPABASE_FUNCTIONS_URL="$SUPABASE_URL/functions/v1" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
```

Play Store용은 같은 옵션으로 `flutter build appbundle --release`를 실행한다. 출시 전 서명된 산출물에서 앱 실행·6개 게시판·검색·페이지 이동·공지 URL·알림 권한 거부/설정 복귀·설정 저장 복원을 확인한다. 테스트 기기의 foreground/background/종료 상태에서 FCM 수신과 알림 탭 URL도 확인한다. 기기 복구와 자동 백업에서 설치 인증 비밀값이 복제되지 않도록 Android 백업은 끈다.

## 장애와 롤백

- 발송은 한 건씩 획득하고, 수락이 확인된 알림은 재발송하지 않는다. FCM 수락 직후 서버가 종료되면 `sending`, 응답 유실은 `DELIVERY_UNKNOWN`으로 남을 수 있다. 외부 FCM과 DB 사이에 분산 트랜잭션이 없으므로 정확히 한 번 전달을 보장하지 않는다.
- 중복 방지를 우선한다. `sending`이나 `DELIVERY_UNKNOWN`을 자동으로 `pending`으로 바꾸지 않는다. 운영자가 FCM 수락 여부를 판단할 수 없으면 목록 확인으로 보완한다.
- 429/5xx의 명확한 거절만 backoff 후 최대 3회 재시도한다. 인증 실패나 일반 404로 기기를 끄지 않는다. 기기 비활성화는 [FCM `UNREGISTERED`](https://firebase.google.com/docs/cloud-messaging/error-codes)에만 적용한다.
- 긴급 중단은 DSU의 두 Cron만 unschedule한다. 이미 발송된 푸시는 취소할 수 없다.
- DB 테이블이나 기존 migration을 삭제·되돌리지 않는다. 검증한 이전 Edge 버전을 재배포하더라도 인증 없는 구버전 `devices` API와 RLS 해제를 되살리지 않는다. 보안 호환이 안 되는 경우 Cron을 중단하고 전진 수정한다.
- 앱은 같은 서명 키와 증가한 versionCode로 복구 버전을 배포한다. Play Store 공개 시 개인정보처리방침과 데이터 보안 양식을 실제 기기 ID·FCM 토큰·설정 저장 범위에 맞게 작성한다.

## 2026-11-08 검증 기록

- Node 단위 테스트 13개, 운영 Edge 공통 로직 테스트 5개 통과.
- Flutter Widget/Client 테스트 16개 및 `flutter analyze` 통과. 320dp·2배 글자·키보드 표시 회귀 검사 포함.
- Docker PostgreSQL에 모든 migration 적용, 권한·원자 저장·고정 상태 전환·동시 claim·Cron 재등록/10분 수집 주기 검증 통과.
- 별도 로컬 Supabase의 실제 Edge API에서 소유권·활성 토큰 충돌·입력 검증·커서·검색·저장 공지 직접 조회 통합 검사 통과.
- 외부 동서대학교 6개 게시판 파싱 통과, 로컬 수집 함수가 128건 저장.
- Android 디버그 APK 빌드·설치 후 게시판 알림/별표 저장의 서버 반영 확인. 테스트 FCM 1건 `sent=1, failed=0` 및 Android notification record의 실제 제목 표시 확인.
- 리뷰어 t3w가 코드와 배포 순서를 검토했고 발견 사항을 반영했다. 현재 터미널 t3x는 메인 구현 담당이다.
- 운영 배포, 운영 Cron 실행, 서명된 release 실행 검증은 미완료다. 현재 운영 프로젝트 접근 권한·release Firebase·서명 키가 없다. Background/종료 상태 FCM과 해당 상태의 알림 탭은 서명된 기기 최종 검증에 남긴다.

## 후속 릴리스 준비

사용자가 개인 설치용 APK 배포, 운영 `.env` 사용, 기존 Firebase 프로젝트 재사용과 신규 서명 키 생성을 지정했다. 이에 따라 기존 Firebase Android 설정을 release 경로에 복사하고, 신규 릴리스 키와 `android/key.properties`, 누락된 운영 Cron secret을 로컬에 생성했다. 비밀 파일과 서명 키는 Git에 포함하지 않는다. 서비스 계정 JSON 없이 기존 `.env`의 FCM 인증정보를 사용한다.

- 운영 URL의 프로젝트 ID: `kxdumukxhocegsnbcfmz`. 공개 API 키와 서버 키의 접근을 확인했으며 아직 공지 테이블이 없는 빈 프로젝트다.
- 신규 서명 APK: `frontend/build/app/outputs/flutter-apk/app-release.apk` (버전 `0.1.0+1`). 서명 검증과 서버 비밀값 미포함 검사를 통과했다.
- APK SHA-256: `29f0792f2c5aee30bd66cc5a812da150b5348d9e9bd33761b1dbed7d8a1c2801`.
- 서명 인증서 SHA-256: `8c6b5c4b177a015b0dc3e4a0aed91d2895bfd8770174b6003f06b93105227d67`. keystore는 홈 디렉터리의 `.android/keystores/dsu-notifier-release.jks`, 암호는 Git에서 제외된 `frontend/android/key.properties`에 저장한다. 두 파일을 안전하게 백업해야 같은 앱을 업데이트할 수 있다.
- AVD 이름을 확인한 `dsu_nofiter`에만 서명 APK를 설치하고 실행했다. 이후 연결 해제로 화면·권한·FCM의 릴리스 최종 검증은 아직 미완료다. 다른 AVD에는 설치하지 않았다.
- 현재 CLI 계정에는 다른 프로젝트만 보이고, 운영 프로젝트의 Functions 조회가 `403`으로 거절된다. 운영 프로젝트 소유 계정의 CLI 로그인 또는 프로젝트 접근권한이 확보되기 전에는 DB/Edge/Cron 배포를 실행하지 않았다. APK가 생성된 것이 백엔드 배포 완료를 의미하지 않는다.
