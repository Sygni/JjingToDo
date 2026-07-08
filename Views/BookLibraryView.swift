//
//  BookLibraryView.swift
//  JjingToDo
//

import SwiftUI
import CoreData

struct BookLibraryView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Book.dateRead, ascending: false)],
        animation: .default
    )
    private var books: FetchedResults<Book>

    @State private var showingAddBook = false
    @State private var editingBook: Book? = nil
    @State private var bookToDelete: Book? = nil
    @State private var detailBook: Book? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TitleBar()
                    .padding(.top, 20)
                    .padding(.bottom, 12)

                GeometryReader { proxy in
                        let fullW = proxy.size.width
                        let bookW = min(fullW * 0.58, 340)
                        let centerBase = (fullW - bookW) / 2

                        let listSorted: [Book] = Array(books).sorted { a, b in
                            let da = a.dateRead ?? .distantPast
                            let db = b.dateRead ?? .distantPast
                            if da != db { return da > db }
                            return (a.title ?? "") < (b.title ?? "")
                        }

                        let toneFlags = alternatingToneFlags(for: listSorted)

                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(listSorted.enumerated()), id: \.1.objectID) { idx, book in
                                    let key = (book.title ?? "") + "|" + (book.author ?? "")
                                    let jitter = startOffsetX(from: key, maxJitter: 24)
                                    let start = centerBase + jitter
                                    let tone: CGFloat = toneFlags[idx] ? 0.90 : 1.0

                                    HStack(spacing: 0) {
                                        Spacer().frame(width: max(0, start))
                                        BookStackView(book: book, tone: tone)
                                            .frame(width: bookW, alignment: .leading)
                                            .contextMenu {
                                                Button {
                                                    editingBook = book
                                                } label: {
                                                    Label("편집", systemImage: "pencil")
                                                }
                                                Button(role: .destructive) {
                                                    bookToDelete = book
                                                } label: {
                                                    Label("삭제", systemImage: "trash")
                                                }
                                            }
                                        Spacer()
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture { detailBook = book }
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            bookToDelete = book
                                        } label: {
                                            Label("삭제", systemImage: "trash")
                                        }
                                        Button {
                                            editingBook = book
                                        } label: {
                                            Label("편집", systemImage: "pencil")
                                        }
                                        .tint(.blue)
                                    }
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.bottom, 48)
                            .frame(minHeight: proxy.size.height, alignment: .bottom)
                        }
                    }
                }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                AppBackground(imageName: "StackBG")
                    .ignoresSafeArea()
            }
            .overlay(alignment: .topTrailing) {
                Button { showingAddBook = true } label: {
                    Image(systemName: "plus")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .padding(.top, 28)
                        .padding(.trailing, 16)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingAddBook) {
                AddBookView(context: viewContext)
            }
            .sheet(item: $editingBook) { bk in
                EditBookView(
                    vm: BookSearchViewModel(context: viewContext),
                    book: bk
                )
            }
            .sheet(item: $detailBook) { bk in
                BookDetailView(book: bk, context: viewContext)
            }
            .alert("이 책을 삭제할까요?", isPresented: .constant(bookToDelete != nil)) {
                Button("취소", role: .cancel) { bookToDelete = nil }
                Button("삭제", role: .destructive) {
                    if let b = bookToDelete { delete(b) }
                    bookToDelete = nil
                }
            } message: { Text(bookToDelete?.title ?? "") }
        }
    }

    private func delete(_ book: Book) {
        viewContext.delete(book)
        do { try viewContext.save() } catch { print("Delete error: \(error)") }
    }

    private func alternatingToneFlags(for books: [Book]) -> [Bool] {
        var flags: [Bool] = []
        var lastIsKo: Bool? = nil
        var runIndex = 0
        for b in books {
            if let last = lastIsKo, last == b.isKorean {
                runIndex += 1
            } else {
                runIndex = 0
                lastIsKo = b.isKorean
            }
            flags.append(runIndex % 2 == 1)
        }
        return flags
    }
}

// MARK: - 책 상세 보기 (탭하면 표시, 편집으로 바로 연결)
struct BookDetailView: View {
    @ObservedObject var book: Book
    let context: NSManagedObjectContext
    @Environment(\.dismiss) private var dismiss
    @State private var showEdit = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    // 표지
                    if let s = book.coverURL, let url = URL(string: s) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let img): img.resizable().scaledToFill()
                            default: Color.gray.opacity(0.15)
                            }
                        }
                        .frame(width: 140, height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 5)
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(0.12))
                            .frame(width: 140, height: 200)
                            .overlay(
                                Image(systemName: "book.closed")
                                    .font(.largeTitle)
                                    .foregroundStyle(.secondary)
                            )
                    }

                    VStack(spacing: 6) {
                        Text(book.title ?? "")
                            .font(.title3.bold())
                            .multilineTextAlignment(.center)
                        if let author = book.author, !author.isEmpty {
                            Text(author)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(spacing: 0) {
                        if let pub = book.publisher, !pub.isEmpty {
                            infoRow(label: "출판사", value: pub)
                            Divider().padding(.leading, 16)
                        }
                        infoRow(label: "페이지", value: "\(max(1, Int(book.pages)))쪽")
                        Divider().padding(.leading, 16)
                        infoRow(label: "언어", value: book.language ?? (book.isKorean ? "한국어" : "외국어"))
                        Divider().padding(.leading, 16)
                        infoRow(label: "읽은 날짜", value: dateText)
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }
                .padding(.top, 24)
                .padding(.bottom, 32)
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("책 정보")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("편집") { showEdit = true }.bold()
                }
            }
            .sheet(isPresented: $showEdit) {
                EditBookView(vm: BookSearchViewModel(context: context), book: book)
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var dateText: String {
        guard let d = book.dateRead else { return "설정 안 함" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy년 M월 d일"
        return f.string(from: d)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
        .font(.subheadline)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct TitleBar: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "books.vertical.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, Color.black.opacity(0.25))
                .padding(6)
                .background(Circle().fill(Palette.titleIcon))
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)

            Text("Books I've Read")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .kerning(0.5)
                .foregroundStyle(Palette.titleFont)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
}
