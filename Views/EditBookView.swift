//
//  EditBookView.swift
//  JjingToDo
//

import SwiftUI

// MARK: - 표지 선택 섹션 (편집/수동등록 공용)
struct CoverPickerSection: View {
    @Binding var coverURLString: String
    let searchTitle: () -> String
    let searchAuthor: () -> String

    @State private var candidates: [URL] = []
    @State private var isSearching = false
    @State private var didSearch = false

    var body: some View {
        Section("표지") {
            HStack(alignment: .top, spacing: 14) {
                coverPreview
                VStack(alignment: .leading, spacing: 10) {
                    Button {
                        _Concurrency.Task { await searchCovers() }
                    } label: {
                        Label(isSearching ? "검색 중..." : "표지 검색", systemImage: "magnifyingglass")
                    }
                    .disabled(isSearching || searchTitle().trimmingCharacters(in: .whitespaces).isEmpty)

                    if !coverURLString.isEmpty {
                        Button(role: .destructive) {
                            coverURLString = ""
                        } label: {
                            Label("표지 제거", systemImage: "trash")
                        }
                    }
                }
                .buttonStyle(.borderless)   // Form 안에서 행 전체 탭 방지
                Spacer()
            }
            .padding(.vertical, 4)

            if didSearch && !isSearching && candidates.isEmpty {
                Text("검색 결과가 없어요. URL을 직접 입력할 수 있어요.")
                    .font(.footnote).foregroundStyle(.secondary)
            }

            if !candidates.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(candidates, id: \.absoluteString) { url in
                            Button {
                                coverURLString = url.absoluteString
                            } label: {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let img): img.resizable().scaledToFill()
                                    default: Color.gray.opacity(0.2)
                                    }
                                }
                                .frame(width: 56, height: 82)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(coverURLString == url.absoluteString ? Color.accentColor : .clear, lineWidth: 2.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            TextField("표지 이미지 URL 직접 입력", text: $coverURLString)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .font(.footnote)
        }
    }

    @ViewBuilder
    private var coverPreview: some View {
        if let url = URL(string: coverURLString), !coverURLString.isEmpty {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFill()
                default: Color.gray.opacity(0.2)
                }
            }
            .frame(width: 60, height: 88)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.15))
                .frame(width: 60, height: 88)
                .overlay(Image(systemName: "book.closed").foregroundStyle(.secondary))
        }
    }

    @MainActor
    private func searchCovers() async {
        isSearching = true
        didSearch = true
        defer { isSearching = false }

        let title = searchTitle().trimmingCharacters(in: .whitespaces)
        let author = searchAuthor().trimmingCharacters(in: .whitespaces).lowercased()
        guard !title.isEmpty else { candidates = []; return }

        let results = (try? await MultiSourceSearchService().search(query: title)) ?? []

        // 저자 일치 결과 우선 정렬 후 URL 중복 제거
        let sorted = results.sorted { a, b in
            let aMatch = !author.isEmpty && (a.authors.first?.lowercased().contains(author) ?? false)
            let bMatch = !author.isEmpty && (b.authors.first?.lowercased().contains(author) ?? false)
            return aMatch && !bMatch
        }
        var seen = Set<String>()
        candidates = sorted.compactMap(\.coverURL).filter { seen.insert($0.absoluteString).inserted }
        if candidates.count > 12 { candidates = Array(candidates.prefix(12)) }
    }
}

struct EditBookView: View {
    @ObservedObject var vm: BookSearchViewModel
    @ObservedObject var book: Book
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var author: String = ""
    @State private var pageText: String = ""
    @State private var isKorean: Bool = true
    @State private var hasDate: Bool = true
    @State private var dateRead: Date = Date()
    @State private var coverURLString: String = ""
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
                CoverPickerSection(
                    coverURLString: $coverURLString,
                    searchTitle: { title },
                    searchAuthor: { author }
                )
                Section("읽은 날짜") {
                    Toggle("읽은 날짜 있음", isOn: $hasDate)
                    if hasDate {
                        DatePicker("날짜", selection: $dateRead, displayedComponents: [.date])
                    } else {
                        Text("설정 안 함").foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("책 정보 수정")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("저장") { save() }.bold() }
            }
            .onAppear(perform: load)
            .alert("저장 실패", isPresented: $showAlert) {
                Button("확인", role: .cancel) {}
            } message: { Text(alertMsg) }
        }
    }

    private func load() {
        title = book.title ?? ""
        author = book.author ?? ""
        pageText = String(max(1, Int(book.pages)))
        isKorean = book.isKorean
        coverURLString = book.coverURL ?? ""
        if let d = book.dateRead { hasDate = true; dateRead = d }
        else { hasDate = false; dateRead = Date() }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { alertMsg = "제목을 입력해 주세요."; showAlert = true; return }
        guard let pages = Int(pageText), pages > 0 else { alertMsg = "페이지 수를 올바르게 입력해 주세요."; showAlert = true; return }
        do {
            let trimmedCover = coverURLString.trimmingCharacters(in: .whitespacesAndNewlines)
            book.coverURL = trimmedCover.isEmpty ? nil : trimmedCover
            try vm.update(book: book, title: trimmedTitle,
                          author: author.trimmingCharacters(in: .whitespacesAndNewlines),
                          pages: pages, isKorean: isKorean, dateRead: hasDate ? dateRead : nil)
            dismiss()
        } catch { alertMsg = error.localizedDescription; showAlert = true }
    }
}
