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

    @State private var containerSize: CGSize = .zero
    /// 확대 1배일 때 이미지가 놓이는 자리
    @State private var baseFrame: CGRect = .zero
    @State private var cropRect: CGRect = .zero

    @State private var zoom: CGFloat = 1
    @State private var zoomStart: CGFloat? = nil
    @State private var pan: CGSize = .zero
    @State private var panStart: CGSize? = nil
    @State private var gestureStartRect: CGRect? = nil

    private let minSize: CGFloat = 24
    private let handleHit: CGFloat = 44
    private let handleDot: CGFloat = 18
    private let maxZoom: CGFloat = 8

    private enum Corner { case topLeft, topRight, bottomLeft, bottomRight }

    /// 확대·이동이 반영된 실제 이미지 표시 영역
    private var displayRect: CGRect {
        let w = baseFrame.width * zoom
        let h = baseFrame.height * zoom
        return CGRect(x: baseFrame.midX + pan.width - w / 2,
                      y: baseFrame.midY + pan.height - h / 2,
                      width: w, height: h)
    }

    /// 크롭 영역이 있을 수 있는 범위 — 이미지 안이면서 화면 안
    private var cropBounds: CGRect {
        let container = CGRect(origin: .zero, size: containerSize)
        let r = displayRect.intersection(container)
        return r.isNull ? container : r
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                GeometryReader { geo in
                    ZStack {
                        // 이미지 밖 드래그 = 사진 이동
                        Color.black.opacity(0.001)
                            .contentShape(Rectangle())
                            .gesture(panGesture)

                        Image(uiImage: image)
                            .resizable()
                            .frame(width: displayRect.width, height: displayRect.height)
                            .position(x: displayRect.midX, y: displayRect.midY)
                            .allowsHitTesting(false)

                        // 크롭 영역 바깥 어둡게 (even-odd 채우기)
                        Path { p in
                            p.addRect(CGRect(origin: .zero, size: geo.size))
                            p.addRect(cropRect)
                        }
                        .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))
                        .allowsHitTesting(false)

                        cropOutline
                            .allowsHitTesting(false)

                        // 크롭 영역 안쪽 드래그 = 영역 이동
                        Rectangle()
                            .fill(Color.white.opacity(0.001))
                            .frame(width: cropRect.width, height: cropRect.height)
                            .position(x: cropRect.midX, y: cropRect.midY)
                            .gesture(moveGesture)

                        handle(.topLeft,     at: CGPoint(x: cropRect.minX, y: cropRect.minY))
                        handle(.topRight,    at: CGPoint(x: cropRect.maxX, y: cropRect.minY))
                        handle(.bottomLeft,  at: CGPoint(x: cropRect.minX, y: cropRect.maxY))
                        handle(.bottomRight, at: CGPoint(x: cropRect.maxX, y: cropRect.maxY))
                    }
                    .clipped()
                    .simultaneousGesture(zoomGesture)   // 핀치는 어디서나 동작
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
            .shadow(color: .black.opacity(0.5), radius: 2)
            .frame(width: handleHit, height: handleHit)   // 터치 영역 확대
            .contentShape(Rectangle())
            .position(point)
            .gesture(resizeGesture(corner))
    }

    private var controls: some View {
        VStack(spacing: 10) {
            Text("모서리를 끌어 영역을 조절하세요. 두 손가락으로 확대하면 영역 바깥을 끌어 사진을 움직일 수 있어요.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            HStack(spacing: 10) {
                Button("전체 선택") {
                    cropRect = clamped(displayRect)
                }
                Button("세로 띠") {
                    cropRect = narrowStrip(in: cropBounds)
                }
                Button("확대 초기화") {
                    zoom = 1
                    pan = .zero
                    cropRect = clamped(cropRect)
                }
                .disabled(zoom == 1 && pan == .zero)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 12)
    }

    // MARK: - 제스처

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                let start = panStart ?? pan
                if panStart == nil { panStart = start }
                pan = clampedPan(CGSize(width: start.width + value.translation.width,
                                        height: start.height + value.translation.height),
                                 zoom: zoom)
                cropRect = clamped(cropRect)
            }
            .onEnded { _ in panStart = nil }
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let start = zoomStart ?? zoom
                if zoomStart == nil { zoomStart = start }
                zoom = min(max(start * value.magnification, 1), maxZoom)
                pan = clampedPan(pan, zoom: zoom)
                cropRect = clamped(cropRect)
            }
            .onEnded { _ in zoomStart = nil }
    }

    /// 사진을 화면 밖으로 밀어내지 못하게 이동 범위를 제한.
    /// 확대 전(이미지가 화면 안에 다 들어옴)에는 이동이 필요 없으므로 0으로 고정된다.
    private func clampedPan(_ p: CGSize, zoom z: CGFloat) -> CGSize {
        let w = baseFrame.width * z
        let h = baseFrame.height * z
        let limitX = max(0, (w - containerSize.width) / 2)
        let limitY = max(0, (h - containerSize.height) / 2)
        return CGSize(width: min(max(p.width, -limitX), limitX),
                      height: min(max(p.height, -limitY), limitY))
    }

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
        guard container.width > 0, container.height > 0 else { return }
        let frame = fittedRect(container: container, imageSize: image.size)
        guard frame.width > 0, frame.height > 0 else { return }

        let isFirst = containerSize == .zero
        containerSize = container
        baseFrame = frame

        if isFirst {
            cropRect = isSpine ? narrowStrip(in: frame) : frame.insetBy(dx: frame.width * 0.08,
                                                                        dy: frame.height * 0.08)
        } else {
            cropRect = clamped(cropRect)
        }
    }

    private func fittedRect(container: CGSize, imageSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let scale = min(container.width / imageSize.width, container.height / imageSize.height)
        let w = imageSize.width * scale
        let h = imageSize.height * scale
        return CGRect(x: (container.width - w) / 2, y: (container.height - h) / 2, width: w, height: h)
    }

    /// 책등용 기본값 — 가운데 좁은 세로 띠
    private func narrowStrip(in frame: CGRect) -> CGRect {
        let w = max(minSize, frame.width * 0.16)
        return CGRect(x: frame.midX - w / 2, y: frame.minY, width: w, height: frame.height)
    }

    private func clamped(_ r: CGRect) -> CGRect {
        let bounds = cropBounds
        guard bounds.width > 0, bounds.height > 0 else { return r }
        var rect = r
        rect.size.width = min(max(minSize, rect.width), bounds.width)
        rect.size.height = min(max(minSize, rect.height), bounds.height)
        rect.origin.x = min(max(rect.origin.x, bounds.minX), bounds.maxX - rect.width)
        rect.origin.y = min(max(rect.origin.y, bounds.minY), bounds.maxY - rect.height)
        return rect
    }

    private func resized(corner: Corner, translation: CGSize, from start: CGRect) -> CGRect {
        let bounds = cropBounds
        var minX = start.minX, minY = start.minY
        var maxX = start.maxX, maxY = start.maxY

        switch corner {
        case .topLeft:     minX += translation.width; minY += translation.height
        case .topRight:    maxX += translation.width; minY += translation.height
        case .bottomLeft:  minX += translation.width; maxY += translation.height
        case .bottomRight: maxX += translation.width; maxY += translation.height
        }

        minX = max(bounds.minX, min(minX, maxX - minSize))
        maxX = min(bounds.maxX, max(maxX, minX + minSize))
        minY = max(bounds.minY, min(minY, maxY - minSize))
        maxY = min(bounds.maxY, max(maxY, minY + minSize))

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    // MARK: - 크롭 실행

    private func finish() {
        let shown = displayRect
        guard shown.width > 0, shown.height > 0 else { onDone(image); return }
        let normalized = image.normalizedOrientation()
        guard let cg = normalized.cgImage else { onDone(image); return }

        // 화면 좌표 → 원본 픽셀 좌표 (확대·이동 반영)
        let relX = (cropRect.minX - shown.minX) / shown.width
        let relY = (cropRect.minY - shown.minY) / shown.height
        let relW = cropRect.width / shown.width
        let relH = cropRect.height / shown.height

        let px = CGRect(x: relX * CGFloat(cg.width),
                        y: relY * CGFloat(cg.height),
                        width: relW * CGFloat(cg.width),
                        height: relH * CGFloat(cg.height))
            .integral
            .intersection(CGRect(x: 0, y: 0, width: cg.width, height: cg.height))

        guard !px.isNull, px.width >= 1, px.height >= 1,
              let cropped = cg.cropping(to: px) else {
            onDone(image); return
        }
        onDone(UIImage(cgImage: cropped, scale: normalized.scale, orientation: .up))
    }
}
