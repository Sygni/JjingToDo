//
//  SearchBook+Merge.swift
//  JjingToDo
//

import Foundation

extension Array where Element == SearchBook {
    func merged() -> SearchBook? {
        guard let first = self.first else { return nil }

        let title = self.map(\.title)
            .sorted {
                let aKo = $0.range(of: #"\p{Hangul}"#, options: .regularExpression) != nil
                let bKo = $1.range(of: #"\p{Hangul}"#, options: .regularExpression) != nil
                if aKo != bKo { return aKo }
                return $0.count > $1.count
            }
            .first ?? first.title

        let authors = self.map(\.authors).sorted { $0.count > $1.count }.first ?? first.authors

        let pages: Int? = {
            let counts = Dictionary(grouping: self.compactMap(\.pageCount), by: { $0 }).mapValues(\.count)
            if let mode = counts.max(by: { $0.value < $1.value })?.key { return mode }
            return self.compactMap(\.pageCount).max()
        }()

        let lang = self.compactMap(\.languageCode)
            .sorted { ($0?.lowercased() == "ko" ? 0 : 1) < ($1?.lowercased() == "ko" ? 0 : 1) }
            .first ?? first.languageCode

        let cover = self.compactMap(\.coverURL)
            .sorted { $0.absoluteString.count > $1.absoluteString.count }
            .first ?? first.coverURL

        let publisher = self.compactMap(\.publisher).first { !$0.isEmpty } ?? first.publisher

        return SearchBook(id: first.id, title: title, authors: authors, pageCount: pages, languageCode: lang, coverURL: cover, publisher: publisher)
    }
}
