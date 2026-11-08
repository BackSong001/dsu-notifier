# API 명세

앱과 Supabase Edge Functions 사이의 최소 API다. Supabase Auth 없이 디바이스별 인증 비밀값을 사용한다.

## 공통

- Base URL: `https://<supabase-project-ref>.supabase.co/functions/v1`
- Content-Type: `application/json`
- 모든 `/devices` 요청: `x-device-secret` 헤더 필수. 설치 시 생성한 32바이트 이상의 무작위 비밀값이며 서버에는 SHA-256 해시만 저장한다.
- `device_id`: 설치별 UUID. 같은 ID의 재등록과 조회·수정·삭제에는 같은 비밀값이 필요하다.
- 다른 활성 디바이스와 같은 FCM 토큰을 등록하면 거부한다. 구버전 이전은 `RELEASE.md`의 관리자 절차를 따른다.
- 실패 응답: `{"error":"<English error code>","message":"<한국어 설명>"}`

## GET `/notices`

공지 목록을 조회한다.

Query:

- `board_code` optional
- `limit` optional, 기본 20, 최대 100
- `cursor` optional, 응답의 opaque keyset cursor를 그대로 전달
- `search` optional, 최대 200자 제목 부분 문자열 검색

Response `200`:

```json
{
  "items": [
    {
      "id": "uuid",
      "board_code": "MN2000194",
      "board_name": "학사",
      "source_idx": "103653",
      "number": 831,
      "title": "공지 제목",
      "author": "작성자",
      "published_at": "2026-10-29",
      "view_count": 123,
      "url": "https://www.dongseo.ac.kr/kr/index.php?pCode=MN2000194&mode=view&idx=103653",
      "is_notice": false,
      "importance_status": null
    }
  ],
  "next_cursor": null
}
```

## GET `/devices/{device_id}/notice-preferences`

디바이스가 별표로 저장한 공지 ID를 조회한다. 기존 경로와 DB 테이블명은 호환을 위해 유지하며 개별 공지 알람 기능이 아니다.

Response `200`:

```json
{"notice_ids":["notice-uuid"]}
```

## PUT `/devices/{device_id}/notice-preferences`

공지 하나를 저장하거나 저장 취소한다.

Request:

```json
{"notice_id":"notice-uuid","enabled":true}
```

Response `200`:

```json
{"saved":true}
```

`number`는 번호가 없는 고정 공지에서 `null`이다. `importance_status`는 고정 공지에만 `true` 또는 `failed`를 사용하며, 일반 공지는 `null`이다.

## GET `/notices/{id}`

공지 한 건을 조회한다. 목록 응답과 같은 필드를 반환한다.

## POST `/devices/register`

디바이스와 FCM 토큰을 등록하거나 갱신한다.

Request:

```json
{
  "device_id": "11111111-1111-4111-8111-111111111111",
  "fcm_token": "fcm-token",
  "platform": "android"
}
```

Response `200`:

```json
{"device_id":"random-device-id","registered":true}
```

## PUT `/devices/{device_id}/preferences`

게시판별 알림 설정을 저장한다.

Request:

```json
{
  "boards": {
    "MN2000194": true,
    "MN2000191": false,
    "job_plus": true
  }
}
```

Response `200`:

```json
{"saved":true}
```

## GET `/devices/{device_id}/preferences`

디바이스의 기존 게시판별 푸시 구독 설정을 조회한다. 공지별 화면 설정은 `notice-preferences`를 사용한다.

Response `200`:

```json
{
  "boards": {
    "MN2000194": true,
    "MN2000191": false
  }
}
```

## DELETE `/devices/{device_id}`

디바이스와 FCM 토큰을 비활성화한다. 앱 삭제나 알림 해제 시 사용한다.

Response `204`.

## 내부 함수

`scrape-notices`와 `dispatch-notifications`는 앱에 공개하지 않고 Supabase Cron 또는 서버 내부에서만 호출한다.

## GET `/devices/{device_id}/saved-notices`

저장한 공지 자체를 조회한다. `limit`, `cursor`, `search`는 `/notices`와 같으며 응답도 `{items, next_cursor}`다. 전체 최신 100건으로 필터링하지 않으므로 오래된 저장 공지도 복원된다.

공지 목록은 고정 여부·등록일·원본 식별자·UUID 내림차순 keyset 정렬을 사용한다. 저장 공지도 같은 순서다. 잘못된 limit/cursor/게시판은 400, 디바이스 인증 실패는 401, 알 수 없는 경로는 404다.
