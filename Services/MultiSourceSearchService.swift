//
//  MultiSourceSearchService.swift
//  JjingToDo
//

import Foundation

struct MultiSourceSearchService: BookSearchService {
    let aladin = AladinClient()
    let google = GoogleBooksClient()

    func search(query: String) async throws -> [SearchBook] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits  = trimmed.filter(\.isNumber)
        let isISBN  = digits.count == 13 || digits.count == 10 || trimmed.lowercased().hasPrefix("isbn:")

        if isISBN {
            let isbn13 = digits
            async let a: SearchBook?  = try? await aladin.lookup(isbn13: isbn13)
            async let g: [SearchBook] = (try? await google.search(query: "isbn:\(isbn13)")) ?? []

            if let hit = await a {
                return merge(primary: [hit], others: await g)
            } else {
                return await g
            }
        } else {
            async let a: [SearchBook] = (try? await aladin.search(title: trimmed, max: 20)) ?? []
            async let g: [SearchBook] = (try? await google.search(query: "intitle:\(trimmed)")) ?? []
            return merge(primary: await a, others: await g)
        }
    }

    private func merge(primary: [SearchBook], others: [SearchBook]) -> [SearchBook] {
        func key(_ b: SearchBook) -> String {
            "\(b.title.lowercased())|\(b.authors.first?.lowercased() ?? "")"
        }
        var dict: [String: SearchBook] = [:]
        for b in primary { dict[key(b)] = b }
        for o in others {
            let k = key(o)
            if var base = dict[k] {
                if (base.pageCount ?? 0) <= 0, let gp = o.pageCount, gp > 0 { base.pageCount = gp }
                else if let gp = o.pageCount, let bp = base.pageCount, gp > bp { base.pageCount = gp }
                if base.languageCode == nil, let lang = o.languageCode { base.languageCode = lang }
                dict[k] = base
            } else {
                dict[k] = o
            }
        }
        return Array(dict.values)
    }
}
