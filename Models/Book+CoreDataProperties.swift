//
//  Book+CoreDataProperties.swift
//  JjingToDo
//

import Foundation
import CoreData

extension Book {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Book> {
        return NSFetchRequest<Book>(entityName: "Book")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var author: String?
    @NSManaged public var pages: Int32
    @NSManaged public var isKorean: Bool
    @NSManaged public var dateRead: Date?
    @NSManaged public var coverURL: String?
    @NSManaged public var publisher: String?
    @NSManaged public var language: String?
    @NSManaged public var isbn: String?
    @NSManaged public var customCoverFile: String?
    @NSManaged public var customSpineFile: String?
    @NSManaged public var spineHidden: Bool

}

extension Book: Identifiable {}
