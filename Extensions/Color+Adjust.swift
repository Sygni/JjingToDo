//
//  Color+Adjust.swift
//  JjingToDo
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension Color {
    func adjusted(brightness: CGFloat = 1.0, saturation: CGFloat = 1.0) -> Color {
        #if canImport(UIKit)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        r = min(max(r * brightness, 0), 1)
        g = min(max(g * brightness, 0), 1)
        b = min(max(b * brightness, 0), 1)
        let gray = (r + g + b) / 3
        r = gray + (r - gray) * saturation
        g = gray + (g - gray) * saturation
        b = gray + (b - gray) * saturation
        return Color(UIColor(red: r, green: g, blue: b, alpha: a))
        #else
        return self
        #endif
    }
}
