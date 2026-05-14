# 중개사 CRM — 프로젝트 정의서

## 프로젝트 개요

- 부동산 중개사 전용 CRM 및 생산성 도구
- 사용자: 비개발자 현직 5년차 공인중개사
- 목표: 실무에서 즉시 사용 가능한 도구

## 기술 스택

| 항목 | 내용 |
|------|------|
| 파일 구조 | 단일 HTML 파일 (`중개사CRM.html`) |
| 인증/DB | Supabase (supabase-js v2) |
| 오프라인 | localStorage 백업 |
| 언어 | 바닐라 JS, 외부 라이브러리 없음 |

## 비즈니스 모델

- **무료 — 개인 모드**: 혼자 사용, 본인 데이터만
- **유료 — 팀 모드 (추후)**: 대표가 결제, 팀원 초대, 데이터 공유/이관

## 데이터 구조 (Supabase 테이블)

| 테이블 | 설명 |
|--------|------|
| `organizations` | 사무소 (1인 또는 팀) |
| `profiles` | 사용자 (owner / member) |
| `clients` | 고객 |
| `events` | 일정 (현재 로컬 전용) |
| `contracts` | 계약 |
| `payments` | 수수료 |
| `transfers` | 이관 (팀 모드용) |

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
