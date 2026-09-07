import SwiftUI

/// Current observations stay compact; full explanations are behind the learning button.
struct RealityScanFeedbackView: View {
    let telemetry: RealityScanTelemetry

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { statusChips }
            VStack(alignment: .leading, spacing: 6) { statusChips }
        }
        .accessibilityElement(children: .combine)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var statusChips: some View {
        chip(title: "공간", detail: telemetry.meshAnchorCount > 0
             ? "\(telemetry.meshAnchorCount)개 영역" : "비춰줘",
             isReady: telemetry.meshAnchorCount > 0)
        chip(title: "바닥", detail: telemetry.floorAnchorCount > 0 ? "확인됨" : "아래로 비춰줘",
             isReady: telemetry.floorAnchorCount > 0)
    }

    private func chip(title: String, detail: String, isReady: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: isReady ? "checkmark.circle.fill" : "viewfinder")
                .foregroundStyle(isReady ? Color.mint : .white)
                .accessibilityHidden(true)
            Text(title).fontWeight(.semibold)
            Text(detail).monospacedDigit()
        }
        .font(.caption)
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.black.opacity(0.76), in: Capsule())
    }
}

struct RealityScanMeshOverlay: View {
    let patches: [RealityScanPatch]

    var body: some View {
        Canvas { context, size in
            for patch in patches {
                var path = Path()
                path.move(to: point(patch.a, in: size))
                path.addLine(to: point(patch.b, in: size))
                path.addLine(to: point(patch.c, in: size))
                path.closeSubpath()
                context.stroke(path, with: .color((patch.isFloor ? Color.yellow : .cyan).opacity(0.6)),
                               lineWidth: 0.8)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func point(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: point.x * size.width, y: point.y * size.height)
    }
}

/// The reticle samples the center of the camera, while taps re-check their own hit.
struct RealityTargetReticle: View {
    let preview: RealityTargetPreview

    var body: some View {
        Image(systemName: preview.isSelectable ? "checkmark.viewfinder" : "viewfinder")
            .font(.system(size: 30, weight: .medium))
            .foregroundStyle(preview.isSelectable ? Color.mint : .white)
            .shadow(color: .black, radius: 2)
            .frame(width: 32, height: 32)
            .overlay(alignment: .top) {
            if case let .ready(distance) = preview {
                Text("옆면 · \(distance, specifier: "%.1f") m")
                    .font(.caption.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(.black.opacity(0.76), in: Capsule())
                    .fixedSize()
                    .offset(y: 40)
            }
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(preview.guidance)
    }
}
