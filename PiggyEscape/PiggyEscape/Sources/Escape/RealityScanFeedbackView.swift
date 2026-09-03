import SwiftUI

struct RealityScanFeedbackView: View {
    let progress: RealityScanProgress
    let presentation: RealityScanPresentation

    @State private var sweepAtBottom = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: progress.isReady ? "checkmark.circle.fill" : "viewfinder")
                    .foregroundStyle(progress.isReady ? .green : .yellow)
                Text(progress.isReady ? "공간 인식 완료" : "실제 공간 스캔 중")
                    .font(.headline)
                    .foregroundStyle(.white)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.black.opacity(0.22))

                if presentation.showsSceneUnderstanding {
                    GeometryReader { proxy in
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [.clear, .yellow.opacity(0.9), .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 2)
                            .offset(y: sweepAtBottom ? proxy.size.height - 2 : 0)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .accessibilityHidden(true)
                }

                VStack(spacing: 9) {
                    ScanProgressRow(
                        title: "공간 형태",
                        detail: progress.hasMesh ? "AR 메시 감지됨" : "천천히 주변을 비춰줘",
                        isComplete: progress.hasMesh
                    )
                    ScanProgressRow(
                        title: "바닥",
                        detail: progress.hasClassifiedFloor ? "분류된 바닥 감지됨" : "카메라를 아래쪽에도 비춰줘",
                        isComplete: progress.hasClassifiedFloor
                    )
                }
                .padding(14)
            }
            .frame(minHeight: 104)
        }
        .padding(16)
        .frame(maxWidth: 520)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(.white.opacity(0.24), lineWidth: 1)
        }
        .task(id: presentation.showsAnimatedSweep) {
            sweepAtBottom = false
            guard presentation.showsAnimatedSweep else { return }
            withAnimation(.linear(duration: 1.35).repeatForever(autoreverses: true)) {
                sweepAtBottom = true
            }
        }
    }
}

private struct ScanProgressRow: View {
    let title: String
    let detail: String
    let isComplete: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle.dotted")
                .foregroundStyle(isComplete ? .green : .white.opacity(0.72))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.78))
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(detail)")
    }
}
