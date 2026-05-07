//
//  ConfirmBookView.swift
//  JjingToDo
//

import SwiftUI
import CoreData

struct ConfirmBookView: View {
    @ObservedObject var vm: BookSearchViewModel
    let candidate: SearchBook

    @State private var title: String
    @State private var author: String
    @State private var pages: String
    @State private var isKorean: Bool
    @State private var dateRead: Date = Date()

    @Environment(\.dismiss) private var dismiss

    init(vm: BookSearchViewModel, candidate: SearchBook) {
        self.vm = vm
        self.candidate = candidate
        _title = State(initialValue: candidate.title)
        _author = State(initialValue: candidate.authors.first ?? "")
        _pages = State(initialValue: candidate.pageCount.map(String.init) ?? "")
        let lang = candidate.languageCode?.lowercased()
        _isKorean = State(initialValue: (lang == "ko") || candidate.title.contains { $0 >= "가" && $0 <= "힣" })
    }

    var body: some View {
        Form {
            Section {
                HStack(alignment: .top, spacing: 16) {
                    AsyncImage(url: candidate.coverURL) { phase in
                        switch phase {
                        case .empty: Color.gray.opacity(0.2)
                        case .success(let img): img.resizable().scaledToFill()
                        case .failure: Image(systemName: "book.closed").font(.system(size: 40))
                        @unknown default: Color.gray.opacity(0.2)
                        }
                    }
                    .frame(width: 80, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 6) {
                        Text(title).font(.headline)
                        if !author.isEmpty { Text(author).font(.subheadline).foregroundStyle(.secondary) }
                        if let lang = candidate.languageCode?.uppercased() {
                            Text(lang).font(.caption)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(.thinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }
            }

            Section(header: Text("세부 입력")) {
                TextField("제목", text: $title)
                TextField("저자", text: $author)
                TextField("페이지 수", text: $pages).keyboardType(.numberPad)
                Toggle("한국어 책", isOn: $isKorean)
            }

            Section(header: Text("읽은 날짜")) {
                DatePicker("완료일", selection: $dateRead, displayedComponents: .date)
            }
        }
        .navigationTitle("책 확인")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("저장") { save() }
            }
        }
    }

    private func save() {
        vm.addToLibrary(
            candidate,
            overrideTitle: title.trimmingCharacters(in: .whitespaces),
            overrideAuthor: author.trimmingCharacters(in: .whitespaces),
            overridePages: Int(pages),
            overrideIsKorean: isKorean,
            dateRead: dateRead
        )
        dismiss()
    }
}
