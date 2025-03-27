# 🛠️ JjingTodo 개발 로그

## 2025-03-24
- XCode 설치, 개발환경 구축
- Hello World!
- JjingTodo 프로젝트 생성
- 기본 리스트, 항목 입력 구현
- 포인트 누적, 프로그레스바 추가
- 탭 분리(할일, 보상 기록)
- UI 요소에 선호 색상 적용

## 2025-03-25
- GitHub 저장소 연결 완료
- RewardLevel enum 도입하여 보상 구조 개선
- Picker로 보상 선택 UI 추가
- 포인트 계산 방식 간소화 (enum 정리)
- saveData 구조 정리 (ContentView.swift로 이동)
- 보상 환전 체크 & 정렬 기능 추가


## 2025-03-26
- fix: 텍스트 색상 primary로 변경해 라이트/다크모드 대응
- feat: 할 일 수정 기능 추가 및 스와이프 UI 개선
  - 각 항목 스와이프 시 수정/삭제 버튼 표시
  - 수정 시 텍스트 필드 팝업으로 제목 편집 가능
  - 버튼에 아이콘 추가 및 색상 통일

## 2025-03-27
버전 1.1 / 빌드 20250327 업데이트 (CoreData 리팩토링)
- ✅ Core Data 전환 완료
  - 기존 UserDefaults 기반 로직 완전히 제거
  - TaskEntity / RedemptionEntity 정의 및 .xcdatamodel 구성
  - 투두 추가, 수정, 삭제, 완료처리, 보상 쿠폰 기능 모두 Core Data로 연결
  - TaskEntity에 rewardLevel, completedAt 등 커스텀 프로퍼티 포함
  - safeTitle / reward 등 확장 기능도 따로 정리
- 🔁 기존 UI 흐름 대부분 유지하면서 내부 저장 방식만 변경
- 🧹 불필요한 saveData/loadData 함수 및 구 코드 제거
- 🧪 시뮬레이터 / 실기기 테스트 모두 완료
- 🐛 Core Data 연동 과정 중 발생한 에러들 해결 (중복 Identifiable, 빌드 경로 문제 등)
- 📁 코드 구조 일부 정리 (뷰 컴포넌트 분할)
- 💾 안정적인 상태로 커밋 + push 완료 (Git 충돌도 해결함!)
