//
//  Config.swift
//  JjingToDo
//

import Foundation

enum Config {
    static var googleBooksKey: String {
        (Bundle.main.infoDictionary?["GOOGLE_BOOKS_KEY"] as? String) ?? ""
    }
}
