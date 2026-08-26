//
//  UserImageStore.swift
//  JjingToDo
//
//  사용자가 직접 올린 표지·책등 이미지 보관소.
//  Book에는 파일명만 저장하고 실제 파일은 Application Support/UserBookImages/에 둔다.
//

import UIKit

enum UserImageStore {
    private static let memCache = NSCache<NSString, UIImage>()

    private static let dir: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let d = base.appendingPathComponent("UserBookImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()

    static func url(for filename: String) -> URL {
        dir.appendingPathComponent(filename)
    }

    static func image(named filename: String?) -> UIImage? {
        guard let filename, !filename.isEmpty else { return nil }
        if let hit = memCache.object(forKey: filename as NSString) { return hit }
        guard let img = UIImage(contentsOfFile: url(for: filename).path) else { return nil }
        memCache.setObject(img, forKey: filename as NSString)
        return img
    }

    /// 이미지를 저장하고 파일명을 반환. 너무 큰 사진은 긴 변 1600pt로 줄여 보관.
    @discardableResult
    static func save(_ image: UIImage, kind: String) -> String? {
        let resized = downscaled(image, maxDimension: 1600)
        guard let data = resized.jpegData(compressionQuality: 0.9) else { return nil }
        let filename = "\(kind)_\(UUID().uuidString).jpg"
        do {
            try data.write(to: url(for: filename), options: .atomic)
            memCache.setObject(resized, forKey: filename as NSString)
            return filename
        } catch {
            print("UserImageStore save 실패: \(error)")
            return nil
        }
    }

    static func delete(_ filename: String?) {
        guard let filename, !filename.isEmpty else { return }
        try? FileManager.default.removeItem(at: url(for: filename))
        memCache.removeObject(forKey: filename as NSString)
    }

    private static func downscaled(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let longSide = max(image.size.width, image.size.height)
        guard longSide > maxDimension, longSide > 0 else { return image }
        let scale = maxDimension / longSide
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        return UIGraphicsImageRenderer(size: newSize).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
