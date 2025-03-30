#
//  auto_organize_jjingtodo.sh
//  JjingToDo
//
//  Created by Jeongah Seo on 3/30/25.
//

#!/bin/bash

# 루트 디렉토리 기준
BASE_DIR="JjingToDo_20250330/JjingToDo"
SRC_DIR="$BASE_DIR/JjingToDo"

# 타겟 폴더 생성
mkdir -p "$BASE_DIR/Sources/Models"
mkdir -p "$BASE_DIR/Sources/ViewModels"
mkdir -p "$BASE_DIR/Sources/Views/Task"
mkdir -p "$BASE_DIR/Sources/Views/Reward"
mkdir -p "$BASE_DIR/Sources/Views/Common"
mkdir -p "$BASE_DIR/Sources/App"
mkdir -p "$BASE_DIR/Sources/Archived/RedemptionEntity"
mkdir -p "$BASE_DIR/Sources/Managers"
mkdir -p "$BASE_DIR/Sources/Extensions"
mkdir -p "$BASE_DIR/Tests/Unit"
mkdir -p "$BASE_DIR/Tests/UI"
mkdir -p "$BASE_DIR/Resources/AppIcons"

# 정확한 파일 이동 매핑
declare -A move_map=(
  ["AddRewardView.swift"]="$BASE_DIR/Sources/Views/Reward"
  ["RewardListView.swift"]="$BASE_DIR/Sources/Views/Reward"
  ["MainTodoView.swift"]="$BASE_DIR/Sources/Views/Task"
  ["ContentView.swift"]="$BASE_DIR/Sources/Views/Common"
  ["DebugToolView.swift"]="$BASE_DIR/Sources/Views/Common"
  ["PointView.swift"]="$BASE_DIR/Sources/Views/Common"
  ["WorkspaceTabView.swift"]="$BASE_DIR/Sources/Views/Common"
  ["TaskEntity+CoreDataClass.swift"]="$BASE_DIR/Sources/Models"
  ["TaskEntity+CoreDataProperties.swift"]="$BASE_DIR/Sources/Models"
  ["TaskEntity+Extensions.swift"]="$BASE_DIR/Sources/Models"
  ["UserEntity+CoreDataClass.swift"]="$BASE_DIR/Sources/Models"
  ["UserEntity+CoreDataProperties.swift"]="$BASE_DIR/Sources/Models"
  ["Model.swift"]="$BASE_DIR/Sources/Models"
  ["Persistence.swift"]="$BASE_DIR/Sources/Managers"
  ["Date+Format.swift"]="$BASE_DIR/Sources/Extensions"
  ["JjingToDoApp.swift"]="$BASE_DIR/Sources/App"
)

# Redemption 관련 보관
archive_files=(
  "RedemptionEntity+CoreDataClass.swift"
  "RedemptionEntity+CoreDataProperties.swift"
  "RedemptionEntity+Extensions.swift"
  "RedemptionHistoryView.swift"
)

# 실제 이동
for filename in "${!move_map[@]}"; do
  src="$SRC_DIR/$filename"
  dst="${move_map[$filename]}"
  if [ -f "$src" ]; then
    echo "📦 Moving $filename → $(basename $dst)"
    mv "$src" "$dst/"
  fi
done

for filename in "${archive_files[@]}"; do
  src="$SRC_DIR/$filename"
  dst="$BASE_DIR/Sources/Archived/RedemptionEntity"
  if [ -f "$src" ]; then
    echo "📁 Archiving $filename"
    mv "$src" "$dst/"
  fi
done

# 테스트/리소스 이동
[ -d "$BASE_DIR/JjingToDoTests" ] && mv "$BASE_DIR/JjingToDoTests" "$BASE_DIR/Tests/Unit"
[ -d "$BASE_DIR/JjingToDoUITests" ] && mv "$BASE_DIR/JjingToDoUITests" "$BASE_DIR/Tests/UI"
[ -d "$BASE_DIR/AppIcons" ] && mv "$BASE_DIR/AppIcons" "$BASE_DIR/Resources/AppIcons"

# 원래 소스 디렉토리 삭제
rm -rf "$SRC_DIR"

echo "✅ 파일 이동 완료! Xcode에서 Add Files to... 로 그룹 다시 구성해줘!"
