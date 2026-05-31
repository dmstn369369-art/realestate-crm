# 중개사 CRM — 프로젝트 정의서

## 프로젝트 개요

- 부동산 중개사 전용 CRM 및 생산성 도구
- 사용자: 비개발자 현직 5년차 공인중개사
- 목표: 실무에서 즉시 사용 가능한 도구

## 기술 스택

| 항목 | 내용 |
|------|------|
| 파일 구조 | 단일 HTML 파일 (`index.html`) |
| 인증/DB | Supabase (supabase-js v2) |
| 오프라인 | localStorage 백업 |
| 언어 | 바닐라 JS, 외부 라이브러리 없음 (차트는 Chart.js 예외 사용) |

## 비즈니스 모델

- **무료 — 개인 모드**: 혼자 사용, 본인 데이터만
- **유료 — 팀 모드 (추후)**: 대표가 결제, 팀원 초대, 데이터 공유/이관

## 데이터 구조 (Supabase 테이블)

| 테이블 | 설명 |
|--------|------|
| `organizations` | 사무소 (1인 또는 팀) |
| `profiles` | 사용자 (owner / member) |
| `clients` | 고객 |
| `events` | 일정 |
| `contracts` | 계약 |
| `payments` | 수수료 |
| `transfers` | 이관 (팀 모드용) _(삭제 후보: 현재 미사용 가능성)_ |
| `properties` | 매물 |
| `property_photos` | 매물 사진 (매물 1건당 여러 장, 별도 테이블) |
| `contacts` | 전화번호부 (대량 연락처) |
| `announcements` | 공지사항 _(삭제 후보: 서비스 공지는 `notices`/`inquiries` 화면 사용, 팀 공지는 `team_notices` 사용)_ |
| `inquiries` | 문의 |
| `admin_users` | 관리자 계정 |
| `deletion_logs` | 삭제 로그 |
| `team_notices` | 팀 공지 |

### properties 테이블 주요 컬럼

| 분류 | 컬럼 | 설명 |
|------|------|------|
| 기본 | `title` | 매물 제목 |
| 기본 | `property_type` | 매물 유형 (`office` / `oneroom` / `commercial` 등) |
| 기본 | `transaction_type` | 거래 유형 (`monthly` 월세 등) |
| 기본 | `address` | 주소 (지번주소 우선 저장) |
| 기본 | `status` | 매물 상태 (진행 중 / 완료 등) |
| 가격 | `price_sale` | 매매가 |
| 가격 | `price_deposit` | 보증금 |
| 가격 | `price_monthly` | 월세 |
| 가격 | `price_management` | 관리비 |
| 정보 | `area_pyeong` | 면적 (평) |
| 정보 | `floor_current` | 현재 층 |
| 정보 | `floor_total` | 건물 전체 층 |
| 정보 | `rooms` | 방 수 |
| 정보 | `bathrooms` | 욕실 수 |
| 정보 | `direction` | 향 |
| 정보 | `move_in_date` | 입주 가능일 |
| 정보 | `move_in_type` | 입주 유형 (즉시 / 협의 등) |
| 주차/엘베 | `parking_type` | 주차 유형 |
| 주차/엘베 | `parking_count` | 주차 가능 대수 |
| 주차/엘베 | `elevator` | 엘리베이터 유무 |
| 특이사항 | `notes` | 특이사항·메모 |

> `properties` 테이블에 `latitude`, `longitude` 컬럼 있음 (2026-05 추가).
> 매물 저장 시 카카오 지오코딩 좌표를 DB에 저장하며, localStorage(`crm5_prop_coords`)에도 병행 저장.
> 매물소개서 PDF 지도 표시 우선순위: DB 좌표 → localStorage 좌표 → 지도 미표시.
> 기기 간 PDF 지도 표시는 DB 좌표 기준.

---

## 핵심 기능

1. 일정 관리 (달력)
2. 고객 관리 (CRM)
3. 계약/수수료 정산
4. 수수료 비율 설정

## 데이터 흐름 원칙

- **로그인 상태** → Supabase 우선 저장 + localStorage 백업
- **비로그인 상태** → localStorage만 사용
- 데이터 추가/수정/삭제 시 양쪽 동기화
- **ID 타입**: Supabase = UUID 문자열, 로컬 = 숫자 (`uid.c++`)

### canUseCloud 판단 패턴 (표준)

```js
const canUseCloud = (
  typeof supabaseClient !== 'undefined' && supabaseClient !== null &&
  typeof currentUser !== 'undefined' && currentUser !== null &&
  typeof currentOrganization !== 'undefined' && currentOrganization !== null
);
```

---

## 데이터 소유·조회 기준 (중요)

### 조회 기준 요약

| 테이블 | 소유 성격 | SELECT 기준 |
|--------|----------|------------|
| `clients` | 개인 소유 | `user_id = currentUser.id` |
| `events` | 개인 소유 | `user_id = currentUser.id` |
| `contracts` | 개인 소유 | `user_id = currentUser.id` |
| `payments` | 개인 소유 | `user_id = currentUser.id` |
| `contacts` | 개인 소유 | `user_id = currentUser.id` |
| `properties` | **팀 공유** | `organization_id = currentOrganization.id` |

### 이유

- 조직 소속(`organization_id`)은 합류·내보내기로 언제든 변경됨
- 개인 데이터를 `organization_id`로 조회하면 **소속 변경 시 화면에서 사라짐** (데이터 유실이 아닌 조회 누락)
- 매물만 팀 공유 대상이므로 `organization_id` 기준 유지

### INSERT 규칙

- **개인 데이터** INSERT 시 반드시 `user_id: currentUser.id` 포함
- `properties` INSERT 시 `user_id`(등록자) + `organization_id`(팀 식별) 모두 포함

### 팀 통계 집계 기준

- `profiles WHERE organization_id = 현재조직` → 현재 소속 팀원 `user_id` 목록 추출
- `events WHERE user_id IN (팀원목록)` 으로 집계
- 내보낸 팀원은 `profiles`에서 빠지므로 통계에서 **자동 제외** (별도 처리 불필요)

### role 규칙

| 상황 | role 설정 |
|------|---------|
| 초대코드 합류 (`joinTeam`) | `member` |
| 내보내기 후 개인 조직 (`kickTeamMember`) | `owner` |
| 팀 내 일반 팀원 | `member` |

**owner 전용 기능**: 팀원관리 탭(`ttab-members`), 내보내기 버튼(`canKick`), `loadTeamMembers()`, `kickTeamMember()` — 모두 `role==='owner'` 가드

### 합류·내보내기 시 데이터 이전 범위

- **이전 대상**: `properties`(매물) organization_id만 새 조직으로 변경
- **이전 제외**: `clients`, `events`, `contracts`, `payments`, `contacts` — user_id 기준 조회이므로 이전 불필요

---

## 배포 / 인프라

| 항목 | 내용 |
|------|------|
| 호스팅 | GitHub Pages — 저장소 `dmstn369369-art/realestate-crm` |
| 도메인 | `brokid.kr` (CNAME 파일로 연결) |
| 배포 트리거 | `main` 브랜치에 push 시 자동 배포 (GitHub 내부 dynamic 워크플로우) |
| 빌드 설정 | Settings → Pages → Source: Deploy from a branch / main / /(root) |

### 배포 안 될 때 점검 순서

1. `githubstatus.com` — GitHub 전체 장애 여부 확인
2. Settings → Pages — 발행 상태(Source 설정) 확인. 이상 없으면 Source를 "None"으로 저장 후 다시 원복하면 트리거 재등록됨
3. Actions 탭 — `pages build and deployment` 워크플로우 실행 기록 확인
4. 계정 사용량(`github.com/settings/billing`) — 무료 계정의 경우 월별 빌드/대역폭 한도 확인

---

## 외부 연동

### 도로명주소 검색 API (행정안전부)
- 엔드포인트: `https://business.juso.go.kr/addrlink/addrLinkApi.do`
- 인증: 승인키 (`JUSO_API_KEY` 상수) — 값은 소스에만 보관, 문서에 기재 금지
- 용도: 주소 검색 결과에서 `admCd`, `lnbrMnnm`, `lnbrSlno` 등 건축물대장 조회용 코드 추출

### 건축물대장 조회 (Supabase Edge Function)
- Function 이름: `building-info`
- 호출: `supabaseClient.functions.invoke('building-info', { body: { sigunguCd, bjdongCd, bun, ji } })`
- 인증: Supabase Secret `BLD_API_KEY` — Edge Function 내부에서만 사용, 클라이언트에 노출 금지
- 응답 형태: `{ title, recap, floor, expos, area }`

### 카카오 지도 SDK
- SDK URL: `//dapi.kakao.com/v2/maps/sdk.js?appkey=...&libraries=services&autoload=false`
- 인증: JavaScript 키 (`KAKAO_JS_KEY` 상수) — 값은 소스에만 보관, 문서에 기재 금지
- 허용 도메인: `brokid.kr` (카카오 개발자 콘솔에 등록 필요)
- 초기화: `autoload=false` → `kakao.maps.load(callback)` 명시 호출 필요

---

## 주의사항

### ID 타입 혼용 문제
- Supabase UUID(문자열)와 로컬 ID(숫자)는 `===` 비교 시 불일치 발생
- HTML `onclick` 속성에 ID를 넣을 때는 반드시 따옴표로 감쌀 것: `onclick="fn('${c.id}')"`
- 함수 진입부에서 ID 정규화 처리 필요 (UUID면 문자열 유지, 숫자형 문자열이면 parseInt)

### 함수 연관성
수정 시 반드시 연관 함수 동반 확인:

```
saveClient ↔ openClientModal ↔ deleteClientFromModal
saveEvent  ↔ (고객인입 시 clients에도 저장)
일정 / 계약 / 수수료 → 모두 clients.id로 연결됨
```

### 지도-건축물대장 네트워크 경합
- 카카오 SDK 로드·지오코딩 요청과 건축물대장 Edge Function 호출이 동시에 발생하면 대장 조회가 10초 이상 지연되는 현상 확인 (2026-05)
- 해결 패턴: 주소 선택 시 지도 렌더링을 2.5초 타이머로 지연 예약 → 건축물대장 조회 버튼 클릭 시 타이머 즉시 취소 → 조회 완료 후(`finally`) 지도 렌더링 순서로 분리
- 추가로 주소검색 페이지 진입 시 SDK를 미리 조용히 사전 로딩(`_loadKakaoSdk(() => {})`)해 실사용 시점의 경합을 최소화
- 관련 함수: `_scheduleMapRender()`, `renderJusoMap()`, `_loadKakaoSdk()`, `fetchBuildingInfo()`

### 매물 데이터 누락 주의
- 매물 모달에서 데이터를 불러올 때 **모든 컬럼을 명시적으로 누락 없이 읽을 것**
  - 과거 `parking_type`, `parking_count`, `elevator` 등이 빠진 채 저장/표시된 사례 있음
  - 매물소개서 PDF 생성 시에도 위 컬럼이 전부 포함되는지 반드시 확인
- 매물소개서 지도(PDF 내 카카오 지도): DB(`properties.latitude/longitude`) 우선 → 없으면 localStorage(`_loadPropCoords`) → 없으면 지도 미표시
  - 관련 함수: `_savePropCoords()`, `_loadPropCoords()`, `_deletePropCoords()`

### 인증 초기화 순서
- `_authInitialized`, `_dataLoaded` 플래그로 `handleSignedIn` 중복 실행 방지
- `updateAuthUI(user)`는 중복 호출과 무관하게 항상 실행
- 로그아웃 시 두 플래그 반드시 리셋

## 수정 시 체크리스트

함수 하나 수정 후 아래 항목 확인:

- [ ] 추가(insert) · 수정(update) · 삭제(delete) 세 방향 모두 동작
- [ ] 로컬 모드 / 클라우드 모드 양쪽 처리
- [ ] ID 타입 일관성 (UUID vs 숫자)
- [ ] UI 갱신 순서: `persist()` → `renderClients()` → `drawCal()`
- [ ] `canUseCloud` 조건이 표준 패턴과 일치하는지
