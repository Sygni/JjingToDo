//
//  BookSearchViewModel.swift
//  JjingToDo
//

import Foundation
import Combine
import CoreData
import UIKit

@MainActor
final class BookSearchViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var results: [SearchBook] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var addedIDs: Set<String> = []

    private let service: BookSearchService
    private var cancellables = Set<AnyCancellable>()
    private let context: NSManagedObjectContext

    init(service: BookSearchService = MultiSourceSearchService(),
         context: NSManagedObjectContext) {
        self.service = service
        self.context = context
        bind()
        preloadAddedIDs()
    }

    private func bind() {
        $query
            .removeDuplicates()
            .debounce(for: .milliseconds(400), scheduler: DispatchQueue.main)
            .sink { [weak self] q in _Concurrency.Task { await self?.performSearch(q) } }
            .store(in: &cancellables)
    }

    private func preloadAddedIDs() {
        let req = NSFetchRequest<Book>(entityName: "Book")
        if let saved = try? context.fetch(req) {
            addedIDs = Set(saved.map { Self.key(title: $0.title ?? "", author: $0.author ?? "") })
        }
    }

    @MainActor
    func performSearch(_ q: String) async {
        errorMessage = nil
        guard !q.trimmingCharacters(in: .whitespaces).isEmpty else { results = []; return }
        isLoading = true

        let query: String = {
            let digits = q.filter(\.isNumber)
            if digits.count == 13 || digits.count == 10 { return "isbn:\(digits)" }
            if q.contains("/") {
                let parts = q.split(separator: "/", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                let title = parts.first ?? ""
                let author = parts.count > 1 ? parts[1] : ""
                if !author.isEmpty { return "intitle:\(title) inauthor:\(author)" }
            }
            if !q.lowercased().hasPrefix("isbn:") { return "intitle:\(q)" }
            return q
        }()

        do {
            let r1 = try await service.search(query: query)
            if !r1.isEmpty {
                results = r1
            } else if !query.hasPrefix("isbn:") {
                results = (try? await service.search(query: q)) ?? []
            } else {
                results = []
            }
        } catch {
            errorMessage = error.localizedDescription
            results = []
        }
        isLoading = false
    }

    func addToLibrary(_ s: SearchBook, dateRead: Date = Date()) {
        let k = Self.key(title: s.title, author: s.authors.first ?? "")
        if currentSavedKeys().contains(k) { addedIDs.insert(k); return }

        let book = Book(context: context)
        book.id = UUID()
        book.title = s.title
        book.author = s.authors.first ?? ""
        book.pages = Int32(s.pageCount ?? 0)
        book.dateRead = dateRead
        let lang = s.languageCode?.lowercased()
        book.isKorean = (lang == "ko") || s.title.contains { $0 >= "가" && $0 <= "힣" }

        do {
            try context.save()
            addedIDs.insert(k)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } catch { errorMessage = "Save failed: \(error.localizedDescription)" }
    }

    func addToLibrary(_ s: SearchBook,
                      overrideTitle: String?,
                      overrideAuthor: String?,
                      overridePages: Int?,
                      overrideIsKorean: Bool?,
                      dateRead: Date) {
        let finalTitle = overrideTitle?.isEmpty == false ? overrideTitle! : s.title
        let finalAuthor = overrideAuthor?.isEmpty == false ? overrideAuthor! : (s.authors.first ?? "")
        let finalPages = overridePages ?? s.pageCount ?? 0
        let finalIsKorean: Bool = overrideIsKorean ?? {
            let lang = s.languageCode?.lowercased()
            return (lang == "ko") || s.title.contains { $0 >= "가" && $0 <= "힣" }
        }()

        let key = Self.key(title: finalTitle, author: finalAuthor)
        if currentSavedKeys().contains(key) { addedIDs.insert(key); return }

        let book = Book(context: context)
        book.id = UUID()
        book.title = finalTitle
        book.author = finalAuthor
        book.pages = Int32(finalPages)
        book.isKorean = finalIsKorean
        book.dateRead = dateRead

        do {
            try context.save()
            addedIDs.insert(key)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } catch { errorMessage = "Save failed: \(error.localizedDescription)" }
    }

    func resolveByISBN(_ isbn: String) async -> SearchBook? {
        async let g: [SearchBook] = (try? await service.search(query: "isbn:\(isbn)")) ?? []
        async let o: SearchBook? = OpenLibraryClient().fetchByISBN(isbn)
        var cands = await g
        if let oo = await o { cands.append(oo) }
        return cands.merged()
    }

    private func currentSavedKeys() -> Set<String> {
        let req = NSFetchRequest<Book>(entityName: "Book")
        guard let saved = try? context.fetch(req) else { return [] }
        return Set(saved.map { Self.key(title: $0.title ?? "", author: $0.author ?? "") })
    }

    private static func key(title: String, author: String) -> String {
        "\(title.lowercased().trimmingCharacters(in: .whitespaces))|\(author.lowercased())"
    }
}

// MARK: - Manual Add
extension BookSearchViewModel {
    @discardableResult
    func addManualBook(title: String, author: String, pages: Int, isKorean: Bool, dateRead: Date = Date()) throws -> Book {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { throw ManualAddError.invalidTitle }
        let key = Self.key(title: t, author: author)
        if currentSavedKeys().contains(key) { addedIDs.insert(key); throw ManualAddError.duplicate }

        let book = Book(context: context)
        book.id = UUID()
        book.title = t
        book.author = author
        book.pages = Int32(max(1, pages))
        book.isKorean = isKorean
        book.dateRead = dateRead
        try context.save()
        context.processPendingChanges()
        addedIDs.insert(key)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        return book
    }

    enum ManualAddError: Error, LocalizedError {
        case invalidTitle, duplicate
        var errorDescription: String? {
            switch self {
            case .invalidTitle: return "제목을 입력해 주세요."
            case .duplicate: return "이미 등록된 책입니다."
            }
        }
    }
}

// MARK: - Edit / Delete
extension BookSearchViewModel {
    func update(book: Book, title: String, author: String, pages: Int, isKorean: Bool, dateRead: Date?) throws {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { throw EditError.invalidTitle }
        book.title = t
        book.author = author
        book.pages = Int32(max(1, pages))
        book.isKorean = isKorean
        book.dateRead = dateRead
        try context.save()
        context.processPendingChanges()
        addedIDs.insert(Self.key(title: t, author: author))
    }

    func delete(_ book: Book) throws {
        context.delete(book)
        try context.save()
        context.processPendingChanges()
    }

    enum EditError: Error, LocalizedError {
        case invalidTitle
        var errorDescription: String? { "제목을 입력해 주세요." }
    }
}
