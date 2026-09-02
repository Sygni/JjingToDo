//
//  EditBookView.swift
//  JjingToDo
//

import SwiftUI
import PhotosUI

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
// 표지와 책등을 각각 따로 지정·제거할 수 있고, 직접 사진을 올릴 수도 있다.
struct CoverPickerSection: View {
    @Binding var coverURLString: String
    @Binding var isbn: String
    @Binding var customCoverFile: String?
    @Binding var customSpineFile: String?
    @Binding var spineHidden: Bool
    let searchTitle: () -> String
    let searchAuthor: () -> String

    @State private var candidates: [SearchBook] = []
    @State private var isSearching = false
    @State private var didSearch = false
    @State private var kyoboSpine: UIImage? = nil
    @State private var spineChecked = false
    @State private var coverPick: PhotosPickerItem? = nil
    @State private var spinePick: PhotosPickerItem? = nil
    @State private var cropTarget: CropTarget? = nil
    /// 이번 편집에서 새로 만든 파일 — 저장 전에는 책에 이미 붙어 있던 파일을 지우면 안 된다
    @State private var createdFiles: Set<String> = []

    /// 사진을 고른 뒤 크롭 화면에 넘길 대상
    private struct CropTarget: Identifiable {
        let id = UUID()
        let image: UIImage
        let isSpine: Bool
    }

    /// 실제로 책등에 그려질 이미지 (직접 올린 것 > 교보, 제거했으면 없음)
    private var effectiveSpine: UIImage? {
        if let custom = UserImageStore.image(named: customSpineFile) { return custom }
        return spineHidden ? nil : kyoboSpine
    }

    var body: some View {
        Section("표지") {
            HStack(alignment: .top, spacing: 14) {
                coverPreviewView
                VStack(alignment: .leading, spacing: 10) {
                    Button {
                        _Concurrency.Task { await searchCovers() }
                    } label: {
                        Label(isSearching ? "검색 중..." : "표지 검색", systemImage: "magnifyingglass")
                    }
                    .disabled(isSearching || searchTitle().trimmingCharacters(in: .whitespaces).isEmpty)

                    PhotosPicker(selection: $coverPick, matching: .images) {
                        Label("사진에서 고르기", systemImage: "photo")
                    }

                    if hasCover {
                        Button(role: .destructive) {
                            discardIfTemporary(customCoverFile)
                            customCoverFile = nil
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
                Text("검색 결과가 없어요. 사진에서 직접 고르거나 URL을 입력할 수 있어요.")
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

        Section("책등") {
            HStack(alignment: .top, spacing: 14) {
                spinePreviewView
                VStack(alignment: .leading, spacing: 10) {
                    PhotosPicker(selection: $spinePick, matching: .images) {
                        Label("사진에서 고르기", systemImage: "photo")
                    }

                    if customSpineFile == nil && isbn.count == 13 {
                        Button {
                            spineHidden = false
                            CoverImageStore.clearSpineCache(isbn: isbn)
                            _Concurrency.Task { await loadKyoboSpine() }
                        } label: {
                            Label("교보에서 다시 찾기", systemImage: "arrow.clockwise")
                        }
                    }

                    if effectiveSpine != nil {
                        Button(role: .destructive) {
                            discardIfTemporary(customSpineFile)
                            customSpineFile = nil
                            spineHidden = true      // 교보 책등도 쓰지 않음
                        } label: {
                            Label("책등 제거", systemImage: "trash")
                        }
                    }
                }
                .buttonStyle(.borderless)
                Spacer()
            }
            .padding(.vertical, 4)

            Text(spineStatusText)
                .font(.footnote).foregroundStyle(.secondary)

            HStack {
                Text("ISBN13").font(.footnote).foregroundStyle(.secondary)
                TextField("책등 조회용 (예: 9791169087216)", text: $isbn)
                    .keyboardType(.numberPad)
                    .font(.footnote)
            }
            // 항상 화면에 있는 행에 부착해야 핸들러가 유지된다
            .task(id: isbn) { await loadKyoboSpine() }
            .onChange(of: coverPick) { _, item in
                guard let item else { return }
                _Concurrency.Task { await importPhoto(item, asSpine: false) }
            }
            .onChange(of: spinePick) { _, item in
                guard let item else { return }
                _Concurrency.Task { await importPhoto(item, asSpine: true) }
            }
            .fullScreenCover(item: $cropTarget) { target in
                ImageCropView(
                    image: target.image,
                    isSpine: target.isSpine,
                    onCancel: { cropTarget = nil },
                    onDone: { cropped in
                        saveCropped(cropped, asSpine: target.isSpine)
                        cropTarget = nil
                    }
                )
            }
        }
    }

    private var hasCover: Bool {
        customCoverFile != nil || !coverURLString.isEmpty
    }

    private var spineStatusText: String {
        if customSpineFile != nil { return "직접 올린 책등을 사용합니다." }
        if spineHidden { return "책등을 사용하지 않습니다 — 표지 색으로 그려집니다." }
        if !spineChecked { return "책등을 확인하는 중..." }
        if kyoboSpine != nil { return "교보문고 책등 이미지를 사용합니다." }
        if isbn.count == 13 { return "교보에 이 책의 책등 이미지가 없어요. 사진을 직접 올릴 수 있어요." }
        return "ISBN을 입력하면 교보에서 책등을 찾아봅니다."
    }

    // MARK: 미리보기

    @ViewBuilder
    private var coverPreviewView: some View {
        VStack(spacing: 3) {
            if let custom = UserImageStore.image(named: customCoverFile) {
                Image(uiImage: custom)
                    .resizable().scaledToFill()
                    .frame(width: 60, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else if let url = URL(string: coverURLString), !coverURLString.isEmpty {
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
            if customCoverFile != nil {
                Text("직접 올림").font(.caption2).foregroundStyle(.tint)
            }
        }
    }

    @ViewBuilder
    private var spinePreviewView: some View {
        VStack(spacing: 3) {
            if let spine = effectiveSpine {
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
                        Image(systemName: spineHidden ? "minus" : "questionmark")
                            .font(.caption).foregroundStyle(.secondary)
                    )
            }
            if customSpineFile != nil {
                Text("직접 올림").font(.caption2).foregroundStyle(.tint)
            }
        }
    }

    private func candidateCell(_ cand: SearchBook) -> some View {
        let candURL = cand.coverURL?.absoluteString ?? ""
        let candISBN = BookSearchViewModel.isbn13(of: cand) ?? ""
        let selected = customCoverFile == nil && !candURL.isEmpty && coverURLString == candURL
        return Button {
            discardIfTemporary(customCoverFile)
            customCoverFile = nil
            coverURLString = candURL
            if !candISBN.isEmpty, customSpineFile == nil {
                isbn = candISBN       // 표지와 함께 ISBN도 갱신 → 책등도 이 책 기준으로
                spineHidden = false
            }
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
    private func importPhoto(_ item: PhotosPickerItem, asSpine: Bool) async {
        defer {
            if asSpine { spinePick = nil } else { coverPick = nil }
        }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        cropTarget = CropTarget(image: image, isSpine: asSpine)
    }

    @MainActor
    private func saveCropped(_ image: UIImage, asSpine: Bool) {
        let previous = asSpine ? customSpineFile : customCoverFile
        guard let saved = UserImageStore.save(image, kind: asSpine ? "spine" : "cover") else { return }
        createdFiles.insert(saved)
        discardIfTemporary(previous)

        if asSpine {
            customSpineFile = saved
            spineHidden = false
        } else {
            customCoverFile = saved
        }
    }

    /// 이번 편집에서 만든 파일일 때만 삭제 (책에 저장돼 있던 파일은 건드리지 않음)
    private func discardIfTemporary(_ filename: String?) {
        guard let filename, createdFiles.contains(filename) else { return }
        UserImageStore.delete(filename)
        createdFiles.remove(filename)
    }

    @MainActor
    private func loadKyoboSpine() async {
        kyoboSpine = nil
        spineChecked = false
        guard isbn.count == 13 else { spineChecked = true; return }
        kyoboSpine = await CoverImageStore.kyoboSpineRaw(isbn: isbn)
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
    @State private var heightMMText: String = ""
    @State private var thicknessMMText: String = ""
    @State private var isFetchingSize = false
    @State private var customCoverFile: String? = nil
    @State private var customSpineFile: String? = nil
    @State private var spineHidden: Bool = false
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
                Section {
                    HStack {
                        Text("높이").frame(width: 44, alignment: .leading)
                        TextField("mm", text: $heightMMText).keyboardType(.numberPad)
                        Text("mm").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("두께").frame(width: 44, alignment: .leading)
                        TextField("mm", text: $thicknessMMText).keyboardType(.numberPad)
                        Text("mm").foregroundStyle(.secondary)
                    }
                    Button {
                        _Concurrency.Task { await fetchRealSize() }
                    } label: {
                        HStack {
                            Label("알라딘에서 실측값 가져오기", systemImage: "arrow.down.circle")
                            if isFetchingSize { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(isFetchingSize || isbn.filter(\.isNumber).count != 13)
                } header: {
                    Text("실물 크기")
                } footer: {
                    Text("책 높이는 서가에서의 가로 길이를, 두께는 세로 두께를 정해요. 비워 두면 책등 이미지 비율과 쪽수로 추정합니다.")
                }
                CoverPickerSection(
                    coverURLString: $coverURLString,
                    isbn: $isbn,
                    customCoverFile: $customCoverFile,
                    customSpineFile: $customSpineFile,
                    spineHidden: $spineHidden,
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
                ToolbarItem(placement: .cancellationAction) { Button("취소") { cancel() } }
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
        heightMMText = book.heightMM > 0 ? String(book.heightMM) : ""
        thicknessMMText = book.thicknessMM > 0 ? String(book.thicknessMM) : ""
        customCoverFile = book.customCoverFile
        customSpineFile = book.customSpineFile
        spineHidden = book.spineHidden
        if let d = book.dateRead { hasDate = true; dateRead = d }
        else { hasDate = false; dateRead = Date() }
    }

    /// 취소 시 이번 편집에서 새로 올린 사진 파일은 지운다
    private func cancel() {
        if customCoverFile != book.customCoverFile { UserImageStore.delete(customCoverFile) }
        if customSpineFile != book.customSpineFile { UserImageStore.delete(customSpineFile) }
        dismiss()
    }

    /// ISBN으로 알라딘 실측 크기를 받아 채운다
    @MainActor
    private func fetchRealSize() async {
        let clean = isbn.filter(\.isNumber)
        guard clean.count == 13 else { return }
        isFetchingSize = true
        defer { isFetchingSize = false }
        guard let found = try? await AladinClient().lookup(isbn13: clean) else { return }
        if let h = found.heightMM, h > 0 { heightMMText = String(h) }
        if let t = found.thicknessMM, t > 0 { thicknessMMText = String(t) }
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
            // 교체·제거된 기존 사진 파일 정리
            if book.customCoverFile != customCoverFile { UserImageStore.delete(book.customCoverFile) }
            if book.customSpineFile != customSpineFile { UserImageStore.delete(book.customSpineFile) }
            book.heightMM = Int16(heightMMText.filter(\.isNumber).prefix(3)) ?? 0
            book.thicknessMM = Int16(thicknessMMText.filter(\.isNumber).prefix(3)) ?? 0
            book.customCoverFile = customCoverFile
            book.customSpineFile = customSpineFile
            book.spineHidden = spineHidden
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
