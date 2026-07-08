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
            // "제목/저자" 구문 지원
            var aladinQuery = trimmed
            var googleQuery = "intitle:\(trimmed)"
            if trimmed.contains("/") {
                let parts = trimmed.split(separator: "/", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                let t = parts.first ?? ""
                let a = parts.count > 1 ? parts[1] : ""
                aladinQuery = a.isEmpty ? t : "\(t) \(a)"
                googleQuery = a.isEmpty ? "intitle:\(t)" : "intitle:\(t) inauthor:\(a)"
            }
            async let a: [SearchBook] = (try? await aladin.search(title: aladinQuery, max: 20)) ?? []
            async let g: [SearchBook] = (try? await google.search(query: googleQuery)) ?? []
            return merge(primary: await a, others: await g)
        }
    }

    private func merge(primary: [SearchBook], others: [SearchBook]) -> [SearchBook] {
        // 소스별 표기 차이를 흡수하는 정규화 키
        // 예: 알라딘 "채식주의자 (개정판)" / "한강 (지은이)" ↔ 구글 "채식주의자" / "한강"
        func normalize(_ s: String) -> String {
            s.lowercased()
                .replacingOccurrences(of: #"\([^)]*\)"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"[\s\-:·,.!?'"“”‘’]"#, with: "", options: .regularExpression)
        }
        func key(_ b: SearchBook) -> String {
            "\(normalize(b.title))|\(normalize(b.authors.first ?? ""))"
        }
        // 저자 표기가 크게 다를 때를 위한 제목 단독 키 (보조 매칭용)
        func titleKey(_ b: SearchBook) -> String { normalize(b.title) }

        var dict: [String: SearchBook] = [:]
        var order: [String] = []
        for b in primary {
            let k = key(b)
            if dict[k] == nil { order.append(k) }
            dict[k] = b
        }

        var titleIndex: [String: String] = [:]   // titleKey → full key
        for (k, b) in dict { titleIndex[titleKey(b)] = k }

        for o in others {
            let k = key(o)
            // 정확 키 → 없으면 제목 단독 키로 보조 매칭
            let matchKey = dict[k] != nil ? k : titleIndex[titleKey(o)]

            if let mk = matchKey, var base = dict[mk] {
                if (base.pageCount ?? 0) <= 0, let gp = o.pageCount, gp > 0 { base.pageCount = gp }
                else if let gp = o.pageCount, let bp = base.pageCount, gp > bp { base.pageCount = gp }
                if base.languageCode == nil, let lang = o.languageCode { base.languageCode = lang }
                if base.coverURL == nil, let cover = o.coverURL { base.coverURL = cover }
                if base.publisher?.isEmpty != false, let pub = o.publisher { base.publisher = pub }
                dict[mk] = base
            } else {
                if dict[k] == nil { order.append(k) }
                dict[k] = o
                titleIndex[titleKey(o)] = k
            }
        }
        return order.compactMap { dict[$0] }
    }
}
