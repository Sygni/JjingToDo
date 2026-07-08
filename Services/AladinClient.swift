//
//  AladinClient.swift
//  JjingToDo
//

import Foundation

struct AladinClient {
    private let base = "https://www.aladin.co.kr/ttb/api"

    func lookup(isbn13: String) async throws -> SearchBook? {
        let key = Bundle.main.object(forInfoDictionaryKey: "ALADIN_TTB_KEY") as? String ?? ""
        var comp = URLComponents(string: "\(base)/ItemLookUp.aspx")!
        comp.queryItems = [
            .init(name: "ttbkey", value: key),
            .init(name: "itemIdType", value: "ISBN13"),
            .init(name: "ItemId", value: isbn13),
            .init(name: "output", value: "js"),
            .init(name: "Version", value: "20131101"),
            .init(name: "OptResult", value: "subInfo"),
            .init(name: "Cover", value: "Big")
        ]
        let (data, _) = try await URLSession.shared.data(from: comp.url!)
        let decoded = try JSONDecoder().decode(AladinLookupResponse.self, from: data)
        guard let it = decoded.item.first else { return nil }
        return it.toSearchBook()
    }

    func search(title: String, max: Int = 10) async throws -> [SearchBook] {
        let key = Bundle.main.object(forInfoDictionaryKey: "ALADIN_TTB_KEY") as? String ?? ""
        var comp = URLComponents(string: "\(base)/ItemSearch.aspx")!
        comp.queryItems = [
            .init(name: "ttbkey", value: key),
            .init(name: "Query", value: title),
            .init(name: "QueryType", value: "Title"),
            .init(name: "SearchTarget", value: "Book"),
            .init(name: "MaxResults", value: "\(max)"),
            .init(name: "output", value: "js"),
            .init(name: "Version", value: "20131101"),
            .init(name: "OptResult", value: "subInfo"),
            .init(name: "Cover", value: "Big")
        ]
        let (data, _) = try await URLSession.shared.data(from: comp.url!)
        let decoded = try JSONDecoder().decode(AladinSearchResponse.self, from: data)
        return decoded.item.map { $0.toSearchBook() }
    }

    struct AladinSearchResponse: Decodable { let item: [AladinItem] }
    struct AladinLookupResponse: Decodable { let item: [AladinItem] }

    struct AladinItem: Decodable {
        let title: String?
        let author: String?
        let publisher: String?
        let isbn13: String?
        let itemPage: Int?
        let cover: String?
        let subInfo: SubInfo?

        struct SubInfo: Decodable { let itemPage: Int? }

        func toSearchBook() -> SearchBook {
            let pages = itemPage ?? subInfo?.itemPage
            // "홍길동 (지은이), 김철수 (옮긴이)" → "홍길동"
            let cleanAuthor = author?
                .components(separatedBy: ",").first?
                .replacingOccurrences(of: #"\s*\([^)]*\)"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            // 표지 URL 화질 업그레이드 (coversum/cover200 → cover500)
            let coverBig = cover?
                .replacingOccurrences(of: "/coversum/", with: "/cover500/")
                .replacingOccurrences(of: "/cover200/", with: "/cover500/")
                .replacingOccurrences(of: "/cover/", with: "/cover500/")
            return SearchBook(
                id: isbn13 ?? UUID().uuidString,
                title: title ?? "",
                authors: (cleanAuthor?.isEmpty == false) ? [cleanAuthor!] : [],
                pageCount: pages,
                languageCode: nil,
                coverURL: coverBig.flatMap { URL(string: $0.replacingOccurrences(of: "http://", with: "https://")) },
                publisher: publisher?.trimmingCharacters(in: .whitespaces)
            )
        }
    }
}
