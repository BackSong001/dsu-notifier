# API 명세

앱과 Supabase Edge Functions 사이의 최소 API다. 실제 구현 시 Supabase Auth 없이 디바이스 등록 토큰을 사용한다.

## 공통

- Base URL: `https://<supabase-project-ref>.supabase.co/functions/v1`
- Content-Type: `application/json`
- 실패 응답: `{"error":"<English error code>","message":"<한국어 설명>"}`

## GET `/notices`

공지 목록을 조회한다.

Query:

- `board_code` optional
- `limit` optional, 기본 20, 최대 100
- `cursor` optional

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

`number`는 번호가 없는 고정 공지에서 `null`이다. `importance_status`는 고정 공지에만 `true` 또는 `failed`를 사용하며, 일반 공지는 `null`이다.

## GET `/notices/{id}`

공지 한 건을 조회한다. 목록 응답과 같은 필드를 반환한다.

## POST `/devices/register`

디바이스와 FCM 토큰을 등록하거나 갱신한다.

Request:

```json
{
  "device_id": "random-device-id",
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

## DELETE `/devices/{device_id}`

디바이스와 FCM 토큰을 비활성화한다. 앱 삭제나 알림 해제 시 사용한다.

Response `204`.

## 내부 함수

`scrape-notices`와 `dispatch-notifications`는 앱에 공개하지 않고 Supabase Cron 또는 서버 내부에서만 호출한다.
