//
//  EditBookView.swift
//  JjingToDo
//

import SwiftUI

// MARK: - 언어 선택 필드 (편집/수동등록/확인 공용)
// 기본 언어(한국어/영어/일본어)는 세그먼트로, 그 외는 '기타' 선택 후 직접 입력
struct LanguagePickerField: View {
    @Binding var language: String

    private var isPreset: Bool { BookLanguage.presets.contains(language) }

    var body: some View {
        Picker("언어", selection: Binding(
            get: { isPreset ? language : "기타" },
            set: { newVal in
                if newVal == "기타" {
                    if isPreset { language = "" }
                } else {
                    language = newVal
                }
            }
        )) {
            ForEach(BookLanguage.presets, id: \.self) { Text($0).tag($0) }
            Text("기타").tag("기타")
        }
        .pickerStyle(.segmented)

        if !isPreset {
            TextField("언어 직접 입력 (예: 프랑스어)", text: $language)
        }
    }
}

// MARK: - 표지·책등 선택 섹션 (편집/수동등록 공용)
// 후보를 선택하면 표지 URL과 ISBN이 함께 바뀌어 교보 책등도 그 책 기준으로 갱신됨
struct CoverPickerSection: View {
    @Binding var coverURLString: String
    @Binding var isbn: String
    let searchTitle: () -> String
    let searchAuthor: () -> String

    @State private var candidates: [SearchBook] = []
    @State private var isSearching = false
    @State private var didSearch = false
    @State private var spinePreview: UIImage? = nil
    @State private var spineChecked = false

    var body: some View {
        Section("표지 · 책등") {
            HStack(alignment: .top, spacing: 14) {
                coverPreviewView
                spinePreviewView
                VStack(alignment: .leading, spacing: 10) {
                    Button {
                        _Concurrency.Task { await searchCovers() }
                    } label: {
                        Label(isSearching ? "검색 중..." : "표지 검색", systemImage: "magnifyingglass")
                    }
                    .disabled(isSearching || searchTitle().trimmingCharacters(in: .whitespaces).isEmpty)

                    if isbn.count == 13 {
                        Button {
                            CoverImageStore.clearSpineCache(isbn: isbn)
                            _Concurrency.Task { await loadSpine(force: true) }
                        } label: {
                            Label("책등 다시 확인", systemImage: "arrow.clockwise")
                        }
                    }

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

            if spineChecked && spinePreview == nil && isbn.count == 13 {
                Text("이 책은 교보에 책등 이미지가 없어요. 책등은 표지 색으로 그려집니다.")
                    .font(.footnote).foregroundStyle(.secondary)
            }

            if didSearch && !isSearching && candidates.isEmpty {
                Text("검색 결과가 없어요. URL을 직접 입력할 수 있어요.")
                    .font(.footnote).foregroundStyle(.secondary)
            }

            if !candidates.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(candidates) { cand in
                            candidateCell(cand)
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
        .task(id: isbn) { await loadSpine(force: false) }
    }

    // MARK: 미리보기

    @ViewBuilder
    private var coverPreviewView: some View {
        VStack(spacing: 3) {
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
            Text("표지").font(.caption2).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var spinePreviewView: some View {
        VStack(spacing: 3) {
            if let spine = spinePreview {
                Image(uiImage: spine)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            } else {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.12))
                    .frame(width: 30, height: 88)
                    .overlay(
                        Image(systemName: isbn.count == 13 ? "questionmark" : "minus")
                            .font(.caption).foregroundStyle(.secondary)
                    )
            }
            Text("책등").font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func candidateCell(_ cand: SearchBook) -> some View {
        let candURL = cand.coverURL?.absoluteString ?? ""
        let candISBN = BookSearchViewModel.isbn13(from: cand.id) ?? ""
        let selected = !candURL.isEmpty && coverURLString == candURL
        return Button {
            coverURLString = candURL
            isbn = candISBN   // 표지와 함께 ISBN도 갱신 → 책등도 이 책 기준으로
        } label: {
            VStack(spacing: 4) {
                AsyncImage(url: cand.coverURL) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    default: Color.gray.opacity(0.2)
                    }
                }
                .frame(width: 56, height: 82)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(selected ? Color.accentColor : .clear, lineWidth: 2.5)
                )
                Text(cand.title)
                    .font(.caption2)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 64)
                    .foregroundStyle(selected ? Color.accentColor : .secondary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: 로직

    @MainActor
    private func loadSpine(force: Bool) async {
        spinePreview = nil
        spineChecked = false
        guard isbn.count == 13 else { spineChecked = true; return }
        spinePreview = await CoverImageStore.kyoboSpineRaw(isbn: isbn)
        spineChecked = true
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

        // 저자 일치 결과 우선 정렬 후 표지 있는 것만, URL 중복 제거
        let sorted = results.sorted { a, b in
            let aMatch = !author.isEmpty && (a.authors.first?.lowercased().contains(author) ?? false)
            let bMatch = !author.isEmpty && (b.authors.first?.lowercased().contains(author) ?? false)
            return aMatch && !bMatch
        }
        var seen = Set<String>()
        candidates = sorted
            .filter { $0.coverURL != nil }
            .filter { seen.insert($0.coverURL!.absoluteString).inserted }
        if candidates.count > 12 { candidates = Array(candidates.prefix(12)) }
    }
}

struct EditBookView: View {
    @ObservedObject var vm: BookSearchViewModel
    @ObservedObject var book: Book
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var author: String = ""
    @State private var publisher: String = ""
    @State private var pageText: String = ""
    @State private var language: String = "한국어"
    @State private var hasDate: Bool = true
    @State private var dateRead: Date = Date()
    @State private var coverURLString: String = ""
    @State private var isbn: String = ""
    @State private var showAlert = false
    @State private var alertMsg = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("기본 정보") {
                    TextField("제목(필수)", text: $title).textInputAutocapitalization(.sentences)
                    TextField("저자", text: $author)
                    TextField("출판사", text: $publisher)
                    TextField("페이지 수(필수, 숫자)", text: $pageText).keyboardType(.numberPad)
                }
                Section("언어") {
                    LanguagePickerField(language: $language)
                }
                CoverPickerSection(
                    coverURLString: $coverURLString,
                    isbn: $isbn,
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
        publisher = book.publisher ?? ""
        pageText = String(max(1, Int(book.pages)))
        language = book.language ?? (book.isKorean ? "한국어" : "영어")
        coverURLString = book.coverURL ?? ""
        isbn = book.isbn ?? ""
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
            let trimmedISBN = isbn.filter(\.isNumber)
            book.isbn = trimmedISBN.count == 13 ? trimmedISBN : nil
            try vm.update(book: book, title: trimmedTitle,
                          author: author.trimmingCharacters(in: .whitespacesAndNewlines),
                          pages: pages,
                          language: language.trimmingCharacters(in: .whitespaces),
                          publisher: publisher.trimmingCharacters(in: .whitespaces),
                          dateRead: hasDate ? dateRead : nil)
            dismiss()
        } catch { alertMsg = error.localizedDescription; showAlert = true }
    }
}
