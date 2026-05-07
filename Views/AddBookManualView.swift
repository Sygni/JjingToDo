//
//  AddBookManualView.swift
//  JjingToDo
//

import SwiftUI

struct AddBookManualView: View {
    @ObservedObject var vm: BookSearchViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var author: String = ""
    @State private var pageText: String = ""
    @State private var isKorean: Bool = true
    @State private var showAlert = false
    @State private var alertMsg = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("기본 정보") {
                    TextField("제목(필수)", text: $title).textInputAutocapitalization(.sentences)
                    TextField("저자", text: $author)
                    TextField("페이지 수(필수, 숫자)", text: $pageText).keyboardType(.numberPad)
                    Toggle("한국어 책", isOn: $isKorean)
                }
            }
            .navigationTitle("수동 등록")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("저장") { save() }.bold() }
            }
            .alert("저장 실패", isPresented: $showAlert) {
                Button("확인", role: .cancel) {}
            } message: { Text(alertMsg) }
        }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { alertMsg = "제목을 입력해 주세요."; showAlert = true; return }
        guard let pages = Int(pageText), pages > 0 else { alertMsg = "페이지 수를 올바르게 입력해 주세요."; showAlert = true; return }
        do {
            _ = try vm.addManualBook(title: trimmedTitle, author: author.trimmingCharacters(in: .whitespacesAndNewlines), pages: pages, isKorean: isKorean)
            dismiss()
        } catch {
            alertMsg = error.localizedDescription
            showAlert = true
        }
    }
}
