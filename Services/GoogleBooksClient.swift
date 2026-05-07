//
//  GoogleBooksClient.swift
//  JjingToDo
//

import Foundation

private struct GBResponse: Decodable {
    let items: [GBItem]?
}
private struct GBItem: Decodable {
    let id: String
    let volumeInfo: GBVolume
}
private struct GBVolume: Decodable {
    let title: String?
    let authors: [String]?
    let pageCount: Int?
    let language: String?
    let imageLinks: GBImageLinks?
}
private struct GBImageLinks: Decodable {
    let thumbnail: String?
    let smallThumbnail: String?
}

struct GoogleBooksClient: BookSearchService {
    func search(query: String) async throws -> [SearchBook] {
        let key = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_BOOKS_KEY") as? String ?? ""
        let isISBN = query.trimmingCharacters(in: .whitespaces).hasPrefix("isbn:")

        var items: [(String, String)] = [
            ("q", query),
            ("key", key),
            ("printType", "books"),
            ("country", "KR"),
            ("projection", "full"),
        ]

        if isISBN {
            items.append(("maxResults", "5"))
        } else {
            items.append(contentsOf: [
                ("maxResults", "20"),
                ("orderBy", "relevance")
            ])
            if query.range(of: #"\p{Hangul}"#, options: .regularExpression) != nil {
                items.append(("langRestrict", "ko"))
            }
        }

        return try await fetch(qItems: items)
    }

    private func fetch(qItems: [(String, String)]) async throws -> [SearchBook] {
        var comps = URLComponents(string: "https://www.googleapis.com/books/v1/volumes")!
        comps.queryItems = qItems.map { URLQueryItem(name: $0.0, value: $0.1) }
        let url = comps.url!

        let res: GBResponse = try await HTTPClient.shared.get(url, as: GBResponse.self)
        guard let items = res.items else { return [] }

        return items.compactMap { item in
            let v = item.volumeInfo
            let thumb = v.imageLinks?.thumbnail ?? v.imageLinks?.smallThumbnail
            return SearchBook(
                id: item.id,
                title: v.title ?? "(No Title)",
                authors: v.authors ?? [],
                pageCount: v.pageCount,
                languageCode: v.language,
                coverURL: thumb.flatMap { URL(string: $0.replacingOccurrences(of: "http://", with: "https://")) }
            )
        }
    }
}
