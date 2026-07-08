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
    @State private var publisher: String
    @State private var pages: String
    @State private var language: String
    @State private var dateRead: Date = Date()

    @Environment(\.dismiss) private var dismiss

    init(vm: BookSearchViewModel, candidate: SearchBook) {
        self.vm = vm
        self.candidate = candidate
        _title = State(initialValue: candidate.title)
        _author = State(initialValue: candidate.authors.first ?? "")
        _publisher = State(initialValue: candidate.publisher ?? "")
        _pages = State(initialValue: candidate.pageCount.map(String.init) ?? "")
        _language = State(initialValue: BookLanguage.infer(code: candidate.languageCode, title: candidate.title))
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
                TextField("출판사", text: $publisher)
                TextField("페이지 수", text: $pages).keyboardType(.numberPad)
            }

            Section(header: Text("언어")) {
                LanguagePickerField(language: $language)
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
            overrideLanguage: language.trimmingCharacters(in: .whitespaces),
            overridePublisher: publisher.trimmingCharacters(in: .whitespaces),
            dateRead: dateRead
        )
        dismiss()
    }
}
