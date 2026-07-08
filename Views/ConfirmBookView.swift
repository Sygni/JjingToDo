//
//  ConfirmBookView.swift
//  JjingToDo
//

import SwiftUI
import CoreData

struct ConfirmBookView: View {
    @ObservedObject var vm: BookSearchViewModel
    let candidate: SearchBook

    @State private var enriched: SearchBook   // ISBN 2차 조회로 보강된 후보
    @State private var title: String
    @State private var author: String
    @State private var publisher: String
    @State private var pages: String
    @State private var language: String
    @State private var dateRead: Date = Date()
    @State private var isEnriching = false

    @Environment(\.dismiss) private var dismiss

    init(vm: BookSearchViewModel, candidate: SearchBook) {
        self.vm = vm
        self.candidate = candidate
        _enriched = State(initialValue: candidate)
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
                    AsyncImage(url: enriched.coverURL) { phase in
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
                HStack {
                    TextField("페이지 수", text: $pages).keyboardType(.numberPad)
                    if isEnriching { ProgressView() }
                }
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
        .task { await enrichIfNeeded() }
    }

    /// 목록 검색(ItemSearch)엔 쪽수·표지가 빠지는 경우가 많아
    /// ISBN 개별 조회(ItemLookUp + 구글/OpenLibrary)로 빈 필드를 채움
    private func enrichIfNeeded() async {
        let isbn = candidate.id.filter(\.isNumber)
        let missingSomething = candidate.pageCount == nil || candidate.coverURL == nil
            || (candidate.publisher ?? "").isEmpty
        guard missingSomething, isbn.count == 13 else { return }

        isEnriching = true
        defer { isEnriching = false }
        guard let merged = await vm.resolveByISBN(isbn) else { return }

        if enriched.pageCount == nil, let p = merged.pageCount, p > 0 {
            enriched.pageCount = p
            if pages.isEmpty { pages = String(p) }
        }
        if enriched.coverURL == nil, let c = merged.coverURL {
            enriched.coverURL = c
        }
        if (enriched.publisher ?? "").isEmpty, let pub = merged.publisher, !pub.isEmpty {
            enriched.publisher = pub
            if publisher.isEmpty { publisher = pub }
        }
        if enriched.languageCode == nil, let lang = merged.languageCode {
            enriched.languageCode = lang
        }
    }

    private func save() {
        vm.addToLibrary(
            enriched,
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
