import SwiftUI

struct ComparisonView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let model: ComparisonModel
    let retryAvailability: ChapterThreeRetryAvailability
    let onFinish: () -> Void
    let onRetryChapterThree: () -> Void
    let onReset: () -> Void

    @State private var hasAppeared = false

    init(
        reason: ComparisonEntryReason,
        retryAvailability: ChapterThreeRetryAvailability,
        onFinish: @escaping () -> Void,
        onRetryChapterThree: @escaping () -> Void,
        onReset: @escaping () -> Void
    ) {
        model = ComparisonModel(reason: reason)
        self.retryAvailability = retryAvailability
        self.onFinish = onFinish
        self.onRetryChapterThree = onRetryChapterThree
        self.onReset = onReset
    }

    var body: some View {
        ZStack {
            ChapterFourPalette.background
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    ChapterFourSummaryCard(summary: model.summary)

                    VStack(spacing: 14) {
                        ForEach(model.rows) { row in
                            comparisonCard(row)
                        }
                    }
                }
                .frame(maxWidth: 720, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 82)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            actionPanel
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared || reduceMotion ? 0 : 12)
        .onAppear {
            guard !hasAppeared else { return }
            if reduceMotion {
                hasAppeared = true
            } else {
                withAnimation(.easeOut(duration: 0.28)) {
                    hasAppeared = true
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CHAPTER 4 · COMPARISON")
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(ChapterFourPalette.accent)
                .accessibilityHidden(true)

            Text("두 세계의 책임을 비교해봐")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
                .accessibilityAddTraits(.isHeader)

            Text("같은 피기를 움직여도 세계, 좌표, 앞뒤 관계를 만드는 주체는 달라.")
                .font(.body)
                .foregroundStyle(ChapterFourPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func comparisonCard(_ row: ComparisonRow) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(row.axis.rawValue.uppercased())
                .font(.caption.weight(.heavy))
                .tracking(0.8)
                .foregroundStyle(ChapterFourPalette.accent)
                .accessibilityHidden(true)

            Text(row.question)
                .font(.title3.bold())
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 10) {
                    frameworkAnswer(
                        title: "SCENEKIT · 닫힌 세계",
                        symbol: "cube",
                        answer: row.sceneKit,
                        tint: ChapterFourPalette.sceneKit
                    )
                    frameworkAnswer(
                        title: "REALITYKIT · 현실 연결",
                        symbol: "viewfinder",
                        answer: row.realityKit,
                        tint: ChapterFourPalette.realityKit
                    )
                }
            } else {
                HStack(alignment: .top, spacing: 10) {
                    frameworkAnswer(
                        title: "SCENEKIT · 닫힌 세계",
                        symbol: "cube",
                        answer: row.sceneKit,
                        tint: ChapterFourPalette.sceneKit
                    )
                    frameworkAnswer(
                        title: "REALITYKIT · 현실 연결",
                        symbol: "viewfinder",
                        answer: row.realityKit,
                        tint: ChapterFourPalette.realityKit
                    )
                }
            }
        }
        .padding(18)
        .background(ChapterFourPalette.card, in: RoundedRectangle(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.question)
        .accessibilityValue("SceneKit: \(row.sceneKit) RealityKit: \(row.realityKit)")
    }

    private func frameworkAnswer(
        title: String,
        symbol: String,
        answer: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)

            Text(answer)
                .font(.body.weight(.medium))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 15))
    }

    private var actionPanel: some View {
        VStack(spacing: 10) {
            Button(action: onFinish) {
                Label("튜토리얼 완료", systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(ChapterFourButtonStyle(kind: .primary))
            .accessibilityHint("현재 비교 이유를 보존하고 완료 요약으로 이동합니다")

            Button(action: onRetryChapterThree) {
                Label("Chapter 3 다시 하기", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(ChapterFourButtonStyle(kind: .secondary))
            .disabled(!retryAvailability.isAvailable)
            .accessibilityHint(
                retryAvailability.unavailableReason
                    ?? "새로운 현실 세션을 준비해 실제 숨바꼭질을 다시 시작합니다"
            )

            if let unavailableReason = retryAvailability.unavailableReason {
                Label(unavailableReason, systemImage: "info.circle.fill")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(ChapterFourPalette.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: onReset) {
                Label("처음부터 다시 보기", systemImage: "backward.end.fill")
            }
            .buttonStyle(ChapterFourButtonStyle(kind: .tertiary))
            .accessibilityHint("모든 진행을 초기화하고 Chapter 1부터 다시 시작합니다")
        }
        .frame(maxWidth: 720)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(ChapterFourPalette.actionBar)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(.white.opacity(0.16))
                .frame(height: 1)
        }
    }
}

struct ChapterFourSummaryCard: View {
    let summary: ComparisonSummary

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: summary.completedRealHide ? "checkmark.seal.fill" : "flag.fill")
                .font(.title2)
                .foregroundStyle(
                    summary.completedRealHide
                        ? ChapterFourPalette.success
                        : ChapterFourPalette.accent
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 7) {
                Text(summary.title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(summary.message)
                    .font(.body)
                    .foregroundStyle(ChapterFourPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                if let remainingStep = summary.remainingStep {
                    Text(remainingStep)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(ChapterFourPalette.accent)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .background(ChapterFourPalette.summaryCard, in: RoundedRectangle(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(ChapterFourPalette.accent.opacity(0.32), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

enum ChapterFourButtonKind: Equatable {
    case primary
    case secondary
    case tertiary
}

struct ChapterFourButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    let kind: ChapterFourButtonKind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, 18)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                if kind != .primary {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.22), lineWidth: 1)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 16))
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1) : 0.58)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.12),
                value: configuration.isPressed
            )
    }

    private var foregroundColor: Color {
        kind == .primary ? ChapterFourPalette.primaryButtonText : .white
    }

    private var backgroundColor: Color {
        switch kind {
        case .primary: ChapterFourPalette.accent
        case .secondary: .white.opacity(0.14)
        case .tertiary: .black.opacity(0.26)
        }
    }
}

enum ChapterFourPalette {
    static let background = LinearGradient(
        colors: [
            Color(red: 0.035, green: 0.09, blue: 0.14),
            Color(red: 0.045, green: 0.16, blue: 0.20)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let card = Color(red: 0.06, green: 0.14, blue: 0.19)
    static let summaryCard = Color(red: 0.08, green: 0.18, blue: 0.20)
    static let actionBar = Color(red: 0.025, green: 0.07, blue: 0.10).opacity(0.98)
    static let accent = Color(red: 1.0, green: 0.82, blue: 0.20)
    static let success = Color(red: 0.43, green: 0.90, blue: 0.62)
    static let sceneKit = Color(red: 0.54, green: 0.79, blue: 1.0)
    static let realityKit = Color(red: 0.48, green: 0.94, blue: 0.77)
    static let secondaryText = Color.white.opacity(0.82)
    static let primaryButtonText = Color(red: 0.04, green: 0.08, blue: 0.10)
}

#if DEBUG
struct ComparisonView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ComparisonView(
                reason: .completedHide,
                retryAvailability: .available,
                onFinish: {},
                onRetryChapterThree: {},
                onReset: {}
            )
            .previewDisplayName("완료 경로")

            ComparisonView(
                reason: .lidarUnavailable,
                retryAvailability: .unavailable(
                    reason: "LiDAR 지원 기기에서 다시 시도할 수 있어."
                ),
                onFinish: {},
                onRetryChapterThree: {},
                onReset: {}
            )
            .environment(\.dynamicTypeSize, .accessibility3)
            .previewDisplayName("우회 경로 · 큰 글자")
        }
    }
}
#endif
