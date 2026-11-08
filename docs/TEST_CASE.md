# 테스트 케이스

모든 백엔드 테스트 파일은 `backend/__TEST__/`에 둔다. 각 기능은 Red(실패하는 테스트) → Green(최소 구현) → Refactoring(동작을 유지한 정리) 순서로 진행한다.

## 1. 웹 스크래퍼

| ID | 시나리오 | 기대 결과 |
|---|---|---|
| TC-SCR-001 | 6개 게시판의 정상 HTML 수집 | 각 게시판의 공지 목록이 파싱된다 |
| TC-SCR-002 | 번호가 있는 일반 공지 파싱 | 번호, 제목, 작성자, 등록일, 조회수, 절대 URL이 저장된다 |
| TC-SCR-003 | 번호가 없는 고정 공지 파싱 | `number = null`, `is_notice = true`, `source_idx`가 저장된다 |
| TC-SCR-004 | 상대 상세 URL 파싱 | 허용된 동서대학교 호스트의 절대 URL로 변환된다 |
| TC-SCR-005 | 조회수의 쉼표 포함 값 | 숫자로 변환된다 |
| TC-SCR-006 | HTML 구조가 깨진 응답 | 파싱 실패로 기록되고 해당 결과를 정상 수집으로 저장하지 않는다 |
| TC-SCR-007 | HTTP 4xx/5xx | 해당 게시판 실패를 기록하고 다른 게시판 수집은 계속한다 |

## 2. 공지 DB 저장

| ID | 시나리오 | 기대 결과 |
|---|---|---|
| TC-DB-001 | 새 공지 1건 저장 | 공지 1건이 저장된다 |
| TC-DB-002 | 동일 게시판·동일 `idx` 재수집 | 공지 행이 추가되지 않는다 |
| TC-DB-003 | 번호 없는 고정 공지 저장 | `number = null`, `importance_status = true`로 저장된다 |
| TC-DB-004 | 이전 고정 공지가 최신 첫 페이지에 없음 | 해당 행의 `importance_status`가 `failed`가 된다 |
| TC-DB-005 | `failed` 고정 공지가 다시 등장 | `importance_status`가 `true`가 된다 |
| TC-DB-006 | 수집 또는 파싱 실패 | 기존 공지와 `importance_status`를 변경하지 않는다 |
| TC-DB-007 | 새 공지 저장 | 중복 없는 notification outbox가 생성된다 |

## 3. GET 공지 목록

| ID | 시나리오 | 기대 결과 |
|---|---|---|
| TC-API-001 | 공지 목록 GET | DB의 제목, 조회수, 등록일, 번호, URL 등이 응답된다 |
| TC-API-002 | `board_code` 필터 | 해당 게시판만 반환된다 |
| TC-API-003 | `limit`와 cursor 조회 | 중복 없는 다음 페이지가 반환된다 |
| TC-API-004 | 존재하지 않는 공지 조회 | 404 오류가 반환된다 |
| TC-API-005 | 고정 공지 응답 | `number = null`과 `importance_status`가 반환된다 |

## 4. 공지 URL

| ID | 시나리오 | 기대 결과 |
|---|---|---|
| TC-URL-001 | 저장된 각 공지 URL HEAD/GET | HTTP 응답을 받고 동서대학교 공지 상세 URL로 확인된다 |
| TC-URL-002 | 허용되지 않은 호스트 URL | 저장 또는 외부 접속 대상으로 허용하지 않는다 |

실제 사이트를 사용하는 URL 테스트는 네트워크, 사이트 정책, 일시 장애의 영향을 받으므로 fixture 기반 테스트와 분리한다.

## 5. 수집 주기와 동시성

| ID | 시나리오 | 기대 결과 |
|---|---|---|
| TC-JOB-001 | 운영 스케줄 설정 확인 | 수집 함수가 10분마다 실행되도록 설정된다 |
| TC-JOB-002 | 테스트 스케줄 실행 | 테스트 환경에서 1분마다 수집 함수가 실행된다 |
| TC-JOB-003 | 같은 실행이 겹침 | 하나만 처리하고 중복 저장하지 않는다 |
| TC-JOB-004 | 테스트 공지 추가 후 다음 1분 주기 | 새 공지가 감지되고 DB와 outbox에 한 번씩 생성된다 |
| TC-JOB-005 | 수집 중 타임아웃 | 실패를 기록하고 기존 데이터는 유지한다 |

## 6. 알림

| ID | 시나리오 | 기대 결과 |
|---|---|---|
| TC-NOT-001 | 활성 게시판의 새 공지 | 해당 디바이스 outbox가 생성되고 FCM 발송 대상이 된다 |
| TC-NOT-002 | 비활성 게시판의 새 공지 | 해당 디바이스에는 outbox가 생성되지 않는다 |
| TC-NOT-003 | 같은 공지 재시도 | 동일 디바이스에 중복 발송하지 않는다 |
| TC-NOT-008 | 신규 공지 없는 재수집 | 공지 행·outbox를 변경하거나 알림을 생성하지 않는다 |
| TC-NOT-009 | 알람설정 목록 조회 | 해당 디바이스가 알림을 켠 게시판을 카드로 표시한다 |
| TC-NOT-004 | FCM 일시 실패 | 제한된 횟수로 재시도하고 상태를 기록한다 |
| TC-NOT-005 | 만료된 FCM 토큰 | 토큰을 비활성화한다 |
| TC-NOT-006 | Android 13 이상 알림 권한 허용 | 테스트 공지를 발송하고 에뮬레이터에서 실제 알림이 표시되는지 확인한다 |
| TC-NOT-007 | Android 알림 탭 | 해당 공지 URL이 웹브라우저에서 열린다 |

## 7. 디바이스 API와 보안

| ID | 시나리오 | 기대 결과 |
|---|---|---|
| TC-DEV-001 | 유효한 디바이스 등록 | 토큰이 등록·갱신된다 |
| TC-DEV-002 | 빈 device_id 또는 token | 400 오류가 반환된다 |
| TC-SEC-001 | 앱 번들 검사 | service role key와 FCM 비밀값이 없다 |
| TC-SEC-002 | 로그 검사 | FCM 토큰과 비밀값이 기록되지 않는다 |
| TC-SEC-003 | 내부 수집 함수 직접 호출 | 공개 앱 API처럼 임의 호출되지 않는다 |

## 8. Frontend 테스트

Frontend의 시각 디자인과 레이아웃은 `DESIGN_SYSTEM.md`를 따른다. 아래 테스트는 디자인과 독립적인 사용자 동작·데이터 계약을 검증한다.

| ID | 구분 | 시나리오 | 기대 결과 |
|---|---|---|---|
| TC-FE-001 | Widget | 공지 목록 화면 진입 | 로딩 상태가 표시된 후 Backend 공지 목록이 표시된다 |
| TC-FE-002 | Widget | Backend 공지 응답 표시 | 제목, 조회수, 등록일, 번호, 게시판명이 응답 값 그대로 표시된다 |
| TC-FE-003 | Widget | 번호 없는 고정 공지 표시 | 번호 영역이 오류를 내지 않고 `null` 또는 고정 상태로 표시된다 |
| TC-FE-004 | Widget | Backend 오류 응답 | 오류 메시지와 다시 시도 동작이 표시된다 |
| TC-FE-005 | Widget | 공지 0건 응답 | 빈 목록 안내와 새로고침 동작이 표시된다 |
| TC-FE-006 | Widget | 게시판 필터 선택 | 선택한 `board_code`로 Backend를 재조회하고 해당 게시판만 표시한다 |
| TC-FE-007 | Widget | 공지 항목 선택 | 해당 공지 URL 열기 동작을 호출한다 |
| TC-FE-008 | Client | `GET /notices` 호출 | query, limit, cursor가 API 명세대로 전송된다 |
| TC-FE-009 | Client | API 응답 역직렬화 | snake_case 응답이 앱 모델로 정확히 변환된다 |
| TC-FE-010 | Client | HTTP 4xx/5xx 및 timeout | 원문 English error code를 보존하고 사용자용 원인 안내를 표시한다 |
| TC-FE-011 | Device | FCM 토큰 등록 | 앱 시작 또는 토큰 갱신 시 `/devices/register`가 호출된다 |
| TC-FE-012 | Device | Android 알림 권한 허용 | 권한 상태를 활성화로 표시하고 알림 수신 준비를 완료한다 |
| TC-FE-013 | Device | Android 알림 권한 거부 | 설정으로 이동할 수 있는 안내를 표시하고 앱은 공지 조회를 계속한다 |
| TC-FE-014 | Device | 게시판 알림 켜기/끄기 | `/devices/{device_id}/preferences`에 변경값을 저장한다 |
| TC-FE-015 | Integration | 실제 테스트 Backend에서 공지 조회 | Fixture가 아닌 API 응답이 화면에 표시된다 |
| TC-FE-016 | Integration | 새 공지 알림 수신 | 테스트 공지의 알림이 에뮬레이터에 표시된다 |
| TC-FE-017 | Integration | 알림 또는 공지 클릭 | 해당 공지 URL이 외부 브라우저로 열린다 |
| TC-FE-018 | Widget | 게시판 전환 | 목록을 다시 조회하고 1페이지 최상단으로 이동한다 |
| TC-FE-019 | Widget | 당겨서 새로고침 | 현재 게시판의 첫 페이지를 다시 조회한다 |
| TC-FE-020 | Integration | Foreground FCM 수신 | 목록을 자동 갱신하고 Android 알림을 표시한다 |
| TC-FE-021 | Widget | 게시판 알람 설정 | 현재 게시판 옆 종 버튼으로 게시판 전체 알림을 켜고 알람설정에 표시한다 |
| TC-FE-022 | Integration | 게시판 알람 복원 | 앱 재시작 후 서버의 게시판별 알람 상태를 복원한다 |
| TC-FE-023 | Widget | 공지 저장 | 공지 카드의 별표 버튼으로 저장하고 저장된 공지에 표시한다 |
| TC-FE-024 | Integration | 저장 공지 복원 | 앱 재시작 후 서버의 공지별 저장 상태를 복원한다 |

Frontend 테스트는 다음 경계를 사용한다.

- Widget 테스트: Backend 호출을 가짜 Client로 대체하고 화면 상태만 검증한다.
- Client 테스트: HTTP 서버 또는 요청 가짜 객체로 API 계약만 검증한다.
- Integration 테스트: 테스트 Supabase 프로젝트 또는 로컬 Supabase와 Android 에뮬레이터를 사용한다.
- FCM 및 Android 권한 테스트: 실제 에뮬레이터에서만 최종 판정한다.

## 테스트 순서

1. scraper fixture 파싱 Red → Green → Refactoring
2. 공지 저장과 고정 공지 상태 전이 Red → Green → Refactoring
3. GET API와 실제 URL 접속 Red → Green → Refactoring
4. 1분 테스트 수집과 테스트 공지 감지 Red → Green → Refactoring
5. Android 에뮬레이터 알림 권한·FCM·URL 열기 수동/통합 확인
6. Frontend Client API 계약 Red → Green → Refactoring
7. Frontend Widget 상태·필드 표시 Red → Green → Refactoring
8. Frontend와 테스트 Backend 통합 조회·필터·재시도 확인
9. Android 에뮬레이터에서 권한·FCM·URL 열기 최종 확인
