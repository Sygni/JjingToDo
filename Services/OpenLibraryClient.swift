//
//  OpenLibraryClient.swift
//  JjingToDo
//

import Foundation

struct OpenLibraryClient {
    struct OL: Decodable {
        let title: String?
        let number_of_pages: Int?
    }

    func fetchByISBN(_ isbn: String) async -> SearchBook? {
        guard let url = URL(string: "https://openlibrary.org/isbn/\(isbn).json") else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let r = try JSONDecoder().decode(OL.self, from: data)
            let cover = URL(string: "https://covers.openlibrary.org/b/isbn/\(isbn)-L.jpg")
            return SearchBook(
                id: "ol-\(isbn)",
                title: r.title ?? "",
                authors: [],
                pageCount: r.number_of_pages,
                languageCode: nil,
                coverURL: cover
            )
        } catch { return nil }
    }
}
