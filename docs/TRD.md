# 기술 설계서

## 1. 아키텍처

```text
Supabase Cron
    -> Scrape Edge Function
        -> Dongseo HTML pages
        -> PostgreSQL notices
        -> notification_outbox
            -> FCM
                -> Flutter app
```

## 2. 구성요소

컴포넌트별 책임과 실행 흐름은 [`COMPONENTS.md`](./COMPONENTS.md)를 함께 참조한다.

### Flutter 앱

- 공지 목록과 상세 URL 제공
- FCM 토큰 등록
- 게시판별 알림 설정
- Android 알림 권한 요청
- Backend API Client와 화면을 분리해 테스트한다.
- 시각 디자인은 `DESIGN_SYSTEM.md`와 `colors.json`을 따른다.

### Scrape Edge Function

- 게시판 목록 URL 조회
- HTML 목록 파싱
- 제목, 작성자, 날짜, 조회수, 번호, 상세 URL 추출
- 상대 URL을 절대 URL로 변환
- DB에 멱등적으로 저장
- 새 공지의 outbox 생성

### Supabase PostgreSQL

주요 테이블:

- `notices`: 공지 원본과 수집 상태
- `devices`: 디바이스 식별자와 FCM 토큰
- `notification_preferences`: 게시판별 알림 설정
- `notification_outbox`: 발송 대기 및 결과
- `scrape_runs`: 수집 실행 결과와 오류

`notices`의 `number`는 nullable이다. 번호가 없는 고정 공지는 `number = null`이며, `is_notice = true`이다. `importance_status`는 `true`, `failed`, `null` 중 하나다. `true`는 최신 수집에서 첫 페이지에 확인된 고정 공지, `failed`는 이전에는 확인됐지만 최신 첫 페이지에서 확인되지 않은 고정 공지, `null`은 일반 공지를 뜻한다.

핵심 제약:

- `notices(board_code, source_idx)` UNIQUE
- `devices(device_id)` UNIQUE
- `notification_preferences(device_id, board_code)` UNIQUE
- `notification_outbox(notice_id, device_id)` UNIQUE

## 3. 수집 동작

1. Cron이 수집 함수를 10분마다 호출한다.
2. 게시판별 DB 트랜잭션 락으로 스냅샷 저장을 직렬화한다.
3. 6개 게시판의 첫 페이지를 요청한다.
4. `board-list-table`의 행에서 필드를 파싱한다.
5. 상세 링크의 `pCode`, `idx`를 원본 키로 저장한다.
6. 신규 insert 트리거가 같은 트랜잭션에서 outbox를 만든다.
7. 수집 결과를 `scrape_runs`에 기록한다.

고정 공지 상태 갱신은 게시판 수집이 성공하고 목록 파싱이 유효한 경우에만 수행한다. 목록 요청 또는 파싱이 실패하면 기존 공지의 `importance_status`를 변경하지 않는다.

고정 공지 상태 전이는 다음과 같다.

```text
new pinned       -> true
existing pinned  -> true (seen) / failed (not in latest first page)
failed pinned    -> true (seen again)
```

최신 공지는 첫 페이지에 나타나는 현재 사이트 구조를 전제로 한다. 게시판별 고정 공지와 일반 공지를 모두 파싱한다.

## 4. 알림 동작

1. 새 공지와 알림 활성 디바이스를 조회한다.
2. `(notice_id, device_id)` 기준으로 outbox를 생성한다.
3. FCM으로 발송한다.
4. 성공·실패·재시도 횟수를 기록한다.
5. 무효 토큰은 비활성화한다.

DB 저장과 알림 발송 사이의 장애로 알림이 누락되지 않도록 outbox를 사용한다.

## 5. 보안

- 앱에는 Supabase anon key만 포함한다.
- service role key와 FCM 서버 인증정보는 Edge Function Secrets에만 저장한다.
- 디바이스 등록 요청은 서버에서 입력값과 길이를 검증한다.
- 외부 입력인 HTML은 파싱 후 허용된 필드만 저장한다.
- 로그에 토큰과 비밀값을 출력하지 않는다.

## 6. 장애 및 운영

- HTTP 오류는 해당 게시판 수집 실패로 기록하고 다른 게시판 수집은 계속한다.
- 파싱 결과가 비정상적으로 적으면 전체 결과를 정상으로 간주하지 않는다.
- 기존 데이터는 수집 실패로 삭제하지 않는다.
- 알림 발송은 제한된 횟수로 재시도한다.

발송은 한 건씩 `SKIP LOCKED`로 획득한다. 결과 불명 요청은 중복 방지를 위해 자동 재발송하지 않는다. 운영·이전·롤백 절차는 `RELEASE.md`를 따른다.
