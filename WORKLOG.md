# 🛠️ JjingTodo 개발 로그

## 2025-04-22
🔧 오늘의할일 새벽 2시에 리셋 안 되는 문제 수정 → BGTask 디버깅 모드에서는 한계 있어서 & scenePhase로 해결
🔧 오늘의할일 아이템 완료 체크했다 해제할 때 오늘의할일 복귀 안 되는 문제 → todayAssignedAt 초기화 순서 문제 해결
🔧 리스트 셀 어디나 누르면 완료돼버리는 문제 → 체크 아이콘만 반응하게 수정
🔧 키보드 이외 영역 터치 시 키보드 내려가기 기능 유지 → .simultaneousGesture()로 충돌 없이 통합 

## 2025-04-21
➕ 챌린지 탭 + "추구미 보상" 버튼 기능 추가
- ChugumiActionEntity CoreData 모델 설계 완료 (type, timestamp, memo, point)
- 추구미 버튼 기능 추가 ('참기', '하기' 2개 버튼. 포인트 지급: 160점 - 좋아하는 숫자 넣어버림)
- ChallengeTabView 뷰 구조 완성

## 2025-04-20
➕ 오늘 할 일(Today's' Mission) 큐 도입
- 스와이프 오른쪽 → 오늘 할 일로 지정
- 지정된 항목은 02:00에 자동 해제
- 02:00~12:00 사이에만 지정 가능 (제한 알림도 구현됨)
- 오늘 할 일을 오늘 끝내면 포인트 2배 지급 (만료 전 완료 + 중복 방지)
- 백그라운드 스케줄러 BGTaskScheduler 설정
🎨 Today 섹션 분리
- 오늘 항목 배경색 처리
- 섹션 헤더 커스텀

## 2025-04-19
➕ 태스크 타입 기능 추가
- 태스크 타입 추가: personal, study, work
- 태스크 추가 시 태스크 타입 선택 picker 추가 및 기존의 난이도 picker 위치 조정
- 태스크 리스트에 타입에 해당하는 아이콘 표시

## 2025-04-02
🔧 CSV 파일 불러오기 안 되는 문제 수정
- UserEntity의 포인트와 lifetimePoints 값 제대로 반영되도록 수정
- CSV 파싱 및 CoreData 저장 시 에러 로깅 추가
(추후 수정 필요)
userEntity 불러오기 시 일부 값 반영 안 되는 문제

## 2025-03-30
🔧 파일 폴더 구조 개편

## 2025-03-29
✨ CSV 백업/복원 기능 추가 (Task/Reward)
- 파일 앱 연동 (UIFileSharingEnabled)
- 타입 변환 안전 처리 (Int32, UUID 등)
- DebugToolView에 불러오기 버튼 추가
- 백업 완료 시 알림 표시
🎨 AddRewardView 키보드 UX 개선
- submitLabel + onSubmit 조합 적용

## 2025-03-28
✨ 보상 시스템 개선 완료: CoreData 기반 리팩토링 + 디버그 툴 추가
- RewardEntity 추가, 구조 정비 및 UI 개선
- 포인트 CoreData화, 보상 교환/사용 로직 통합
- 디버그툴 추가 (전체 리셋, 포인트 세팅, 보상 테스트용 등)
- TaskEntity 삭제 이슈 해결 및 뷰 동기화 보완

## 2025-03-27
버전 1.1 / 빌드 20250327 업데이트 (CoreData 리팩토링)
- ✅ Core Data 전환 완료 (Task + Redemption)
  - 기존 UserDefaults 기반 로직 완전히 제거
  - TaskEntity / RedemptionEntity 정의 및 .xcdatamodel 구성
  - 투두 추가, 수정, 삭제, 완료처리, 보상 쿠폰 기능 모두 Core Data로 연결
  - TaskEntity에 rewardLevel, completedAt 등 커스텀 프로퍼티 포함
  - safeTitle / reward 등 확장 기능도 따로 정리
  - Core Data 연동 과정 중 발생한 에러들 해결 (중복 Identifiable, 빌드 경로 문제 등)
  - 코드 구조 일부 정리 (뷰 컴포넌트 분할)
- 💾 안정적인 상태로 커밋 + push 완료 (Git 충돌도 해결함!)
- ✅ 버전 & 빌드 번호 화면 표시

## 2025-03-26
- fix: 텍스트 색상 primary로 변경해 라이트/다크모드 대응
- feat: 할 일 수정 기능 추가 및 스와이프 UI 개선
  - 각 항목 스와이프 시 수정/삭제 버튼 표시
  - 수정 시 텍스트 필드 팝업으로 제목 편집 가능
  - 버튼에 아이콘 추가 및 색상 통일

## 2025-03-25
- GitHub 저장소 연결 완료
- RewardLevel enum 도입하여 보상 구조 개선
- Picker로 보상 선택 UI 추가
- 포인트 계산 방식 간소화 (enum 정리)
- saveData 구조 정리 (ContentView.swift로 이동)
- 보상 환전 체크 & 정렬 기능 추가

## 2025-03-24
- XCode 설치, 개발환경 구축
- Hello World!
- JjingTodo 프로젝트 생성
- 기본 리스트, 항목 입력 구현
- 포인트 누적, 프로그레스바 추가
- 탭 분리(할일, 보상 기록)
- UI 요소에 선호 색상 적용
