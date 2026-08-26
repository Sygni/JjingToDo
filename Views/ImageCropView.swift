//
//  ImageCropView.swift
//  JjingToDo
//
//  자유 비율 크롭 화면.
//  iOS 기본 사진 편집기는 종횡비 하한이 있어 책등처럼 좁고 긴 영역을 자를 수 없어서 직접 구현.
//

import SwiftUI
import UIKit

extension UIImage {
    /// EXIF 회전을 픽셀에 반영해 .up 방향으로 정규화 (크롭 좌표 계산을 단순하게)
    func normalizedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        return UIGraphicsImageRenderer(size: size).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

struct ImageCropView: View {
    let image: UIImage
    /// 책등이면 시작 크롭 영역을 좁고 긴 형태로 잡아준다
    var isSpine: Bool = false
    let onCancel: () -> Void
    let onDone: (UIImage) -> Void

    @State private var imageFrame: CGRect = .zero
    @State private var cropRect: CGRect = .zero
    @State private var gestureStartRect: CGRect? = nil

    private let minSize: CGFloat = 24
    private let handleHit: CGFloat = 44
    private let handleDot: CGFloat = 16

    private enum Corner { case topLeft, topRight, bottomLeft, bottomRight }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                GeometryReader { geo in
                    ZStack(alignment: .topLeading) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()

                        // 크롭 영역 바깥 어둡게 (even-odd 채우기)
                        Path { p in
                            p.addRect(CGRect(origin: .zero, size: geo.size))
                            p.addRect(cropRect)
                        }
                        .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))
                        .allowsHitTesting(false)

                        // 크롭 테두리 + 3분할 안내선
                        cropOutline
                            .allowsHitTesting(false)

                        // 내부 드래그 = 영역 이동
                        Rectangle()
                            .fill(Color.white.opacity(0.001))
                            .frame(width: cropRect.width, height: cropRect.height)
                            .position(x: cropRect.midX, y: cropRect.midY)
                            .gesture(moveGesture)

                        // 네 모서리 = 크기 조절
                        handle(.topLeft,     at: CGPoint(x: cropRect.minX, y: cropRect.minY))
                        handle(.topRight,    at: CGPoint(x: cropRect.maxX, y: cropRect.minY))
                        handle(.bottomLeft,  at: CGPoint(x: cropRect.minX, y: cropRect.maxY))
                        handle(.bottomRight, at: CGPoint(x: cropRect.maxX, y: cropRect.maxY))
                    }
                    .contentShape(Rectangle())
                    .onAppear { layout(in: geo.size) }
                    .onChange(of: geo.size) { _, newSize in layout(in: newSize) }
                }
                .background(Color.black)

                controls
            }
            .navigationTitle(isSpine ? "책등 영역 선택" : "표지 영역 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { finish() }.bold()
                }
            }
        }
    }

    // MARK: - 구성 요소

    private var cropOutline: some View {
        ZStack {
            Rectangle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: cropRect.width, height: cropRect.height)
                .position(x: cropRect.midX, y: cropRect.midY)

            // 3분할 선
            Path { p in
                for i in 1...2 {
                    let x = cropRect.minX + cropRect.width * CGFloat(i) / 3
                    p.move(to: CGPoint(x: x, y: cropRect.minY))
                    p.addLine(to: CGPoint(x: x, y: cropRect.maxY))
                    let y = cropRect.minY + cropRect.height * CGFloat(i) / 3
                    p.move(to: CGPoint(x: cropRect.minX, y: y))
                    p.addLine(to: CGPoint(x: cropRect.maxX, y: y))
                }
            }
            .stroke(Color.white.opacity(0.35), lineWidth: 0.5)
        }
    }

    private func handle(_ corner: Corner, at point: CGPoint) -> some View {
        Circle()
            .fill(Color.white)
            .frame(width: handleDot, height: handleDot)
            .shadow(color: .black.opacity(0.4), radius: 2)
            .frame(width: handleHit, height: handleHit)   // 터치 영역 확대
            .contentShape(Rectangle())
            .position(point)
            .gesture(resizeGesture(corner))
    }

    private var controls: some View {
        VStack(spacing: 10) {
            Text("모서리를 끌어 영역을 조절하세요. 비율 제한이 없어 책등처럼 좁은 영역도 지정할 수 있어요.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            HStack(spacing: 10) {
                Button("전체 선택") {
                    withAnimation(.easeInOut(duration: 0.15)) { cropRect = imageFrame }
                }
                Button("세로 띠") {
                    withAnimation(.easeInOut(duration: 0.15)) { cropRect = narrowStrip(in: imageFrame) }
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 12)
    }

    // MARK: - 제스처

    private var moveGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                let start = gestureStartRect ?? cropRect
                if gestureStartRect == nil { gestureStartRect = start }
                var r = start
                r.origin.x += value.translation.width
                r.origin.y += value.translation.height
                cropRect = clamped(r)
            }
            .onEnded { _ in gestureStartRect = nil }
    }

    private func resizeGesture(_ corner: Corner) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let start = gestureStartRect ?? cropRect
                if gestureStartRect == nil { gestureStartRect = start }
                cropRect = resized(corner: corner, translation: value.translation, from: start)
            }
            .onEnded { _ in gestureStartRect = nil }
    }

    // MARK: - 좌표 계산

    private func layout(in container: CGSize) {
        let frame = fittedRect(container: container, imageSize: image.size)
        guard frame.width > 0, frame.height > 0 else { return }
        let hadCrop = imageFrame.width > 0 && cropRect.width > 0
        // 회전 등으로 표시 영역이 바뀌면 기존 선택 비율을 유지한 채 재배치
        let relative: CGRect? = hadCrop ? CGRect(
            x: (cropRect.minX - imageFrame.minX) / imageFrame.width,
            y: (cropRect.minY - imageFrame.minY) / imageFrame.height,
            width: cropRect.width / imageFrame.width,
            height: cropRect.height / imageFrame.height) : nil

        imageFrame = frame
        if let rel = relative {
            cropRect = clamped(CGRect(x: frame.minX + rel.minX * frame.width,
                                      y: frame.minY + rel.minY * frame.height,
                                      width: rel.width * frame.width,
                                      height: rel.height * frame.height))
        } else {
            cropRect = isSpine ? narrowStrip(in: frame) : defaultRect(in: frame)
        }
    }

    private func fittedRect(container: CGSize, imageSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0,
              container.width > 0, container.height > 0 else { return .zero }
        let scale = min(container.width / imageSize.width, container.height / imageSize.height)
        let w = imageSize.width * scale
        let h = imageSize.height * scale
        return CGRect(x: (container.width - w) / 2, y: (container.height - h) / 2, width: w, height: h)
    }

    private func defaultRect(in frame: CGRect) -> CGRect {
        frame.insetBy(dx: frame.width * 0.08, dy: frame.height * 0.08)
    }

    /// 책등용 기본값 — 가운데 좁은 세로 띠
    private func narrowStrip(in frame: CGRect) -> CGRect {
        let w = max(minSize, frame.width * 0.16)
        return CGRect(x: frame.midX - w / 2, y: frame.minY, width: w, height: frame.height)
    }

    private func clamped(_ r: CGRect) -> CGRect {
        guard imageFrame.width > 0 else { return r }
        var rect = r
        rect.size.width = min(max(minSize, rect.width), imageFrame.width)
        rect.size.height = min(max(minSize, rect.height), imageFrame.height)
        rect.origin.x = min(max(rect.origin.x, imageFrame.minX), imageFrame.maxX - rect.width)
        rect.origin.y = min(max(rect.origin.y, imageFrame.minY), imageFrame.maxY - rect.height)
        return rect
    }

    private func resized(corner: Corner, translation: CGSize, from start: CGRect) -> CGRect {
        var minX = start.minX, minY = start.minY
        var maxX = start.maxX, maxY = start.maxY

        switch corner {
        case .topLeft:     minX += translation.width; minY += translation.height
        case .topRight:    maxX += translation.width; minY += translation.height
        case .bottomLeft:  minX += translation.width; maxY += translation.height
        case .bottomRight: maxX += translation.width; maxY += translation.height
        }

        minX = max(imageFrame.minX, min(minX, maxX - minSize))
        maxX = min(imageFrame.maxX, max(maxX, minX + minSize))
        minY = max(imageFrame.minY, min(minY, maxY - minSize))
        maxY = min(imageFrame.maxY, max(maxY, minY + minSize))

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    // MARK: - 크롭 실행

    private func finish() {
        guard imageFrame.width > 0, imageFrame.height > 0 else { onDone(image); return }
        let normalized = image.normalizedOrientation()
        guard let cg = normalized.cgImage else { onDone(image); return }

        // 화면 좌표 → 원본 픽셀 좌표
        let relX = (cropRect.minX - imageFrame.minX) / imageFrame.width
        let relY = (cropRect.minY - imageFrame.minY) / imageFrame.height
        let relW = cropRect.width / imageFrame.width
        let relH = cropRect.height / imageFrame.height

        let px = CGRect(x: relX * CGFloat(cg.width),
                        y: relY * CGFloat(cg.height),
                        width: relW * CGFloat(cg.width),
                        height: relH * CGFloat(cg.height))
            .integral
            .intersection(CGRect(x: 0, y: 0, width: cg.width, height: cg.height))

        guard px.width >= 1, px.height >= 1, let cropped = cg.cropping(to: px) else {
            onDone(image); return
        }
        onDone(UIImage(cgImage: cropped, scale: normalized.scale, orientation: .up))
    }
}
