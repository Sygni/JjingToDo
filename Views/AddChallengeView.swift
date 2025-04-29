//
//  AddChallengeView.swift
//  JjingToDo
//
//  Created by Jeongah Seo on 4/30/25.
//

import SwiftUI

struct AddChallengeView: View {
    @Binding var title: String
    var onSave: () -> Void
    var onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("챌린지 이름")) {
                    TextField("예: 매일 투두 완료하기", text: $title)
                }
            }
            .navigationTitle("새 챌린지 추가")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("추가", action: onSave)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
