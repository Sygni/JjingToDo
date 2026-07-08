//
//  BookSearchService.swift
//  JjingToDo
//

import Foundation

struct SearchBook: Identifiable, Hashable {
    let id: String
    var title: String
    var authors: [String]
    var pageCount: Int?
    var languageCode: String?
    var coverURL: URL? = nil
    var publisher: String? = nil
}

protocol BookSearchService {
    func search(query: String) async throws -> [SearchBook]
}

// MARK: - 언어 표기 헬퍼
enum BookLanguage {
    /// 선택지로 항상 노출되는 기본 언어
    static let presets = ["한국어", "영어", "일본어"]

    /// ISO 언어 코드 → 한국어 표기 (모르는 코드는 nil)
    static func name(fromCode code: String?) -> String? {
        guard let code = code?.lowercased() else { return nil }
        switch String(code.prefix(2)) {
        case "ko": return "한국어"
        case "en": return "영어"
        case "ja": return "일본어"
        case "zh": return "중국어"
        case "fr": return "프랑스어"
        case "de": return "독일어"
        case "es": return "스페인어"
        case "it": return "이탈리아어"
        case "ru": return "러시아어"
        default: return nil
        }
    }

    /// 제목/언어코드로 언어 추정 (검색 결과 저장 시 기본값)
    static func infer(code: String?, title: String) -> String {
        if let n = name(fromCode: code) { return n }
        if title.contains(where: { $0 >= "가" && $0 <= "힣" }) { return "한국어" }
        return "영어"
    }
}
