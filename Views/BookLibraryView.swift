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
