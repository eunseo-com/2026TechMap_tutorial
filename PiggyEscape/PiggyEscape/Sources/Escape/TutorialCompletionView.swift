import SwiftUI

struct TutorialCompletionView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let model: ComparisonModel
    let retryAvailability: ChapterThreeRetryAvailability
    let onRetryChapterThree: () -> Void
    let onReset: () -> Void

    @State private var hasAppeared = false

    init(
        reason: ComparisonEntryReason,
        retryAvailability: ChapterThreeRetryAvailability,
        onRetryChapterThree: @escaping () -> Void,
        onReset: @escaping () -> Void
    ) {
        model = ComparisonModel(reason: reason)
        self.retryAvailability = retryAvailability
        self.onRetryChapterThree = onRetryChapterThree
        self.onReset = onReset
    }

    var body: some View {
        ZStack {
            ChapterFourPalette.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 22) {
                    completionMark

                    VStack(spacing: 10) {
                        Text(completionTitle)
                            .font(.largeTitle.bold())
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)

                        Text(completionMessage)
                            .font(.title3)
                            .foregroundStyle(ChapterFourPalette.secondaryText)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    ChapterFourSummaryCard(summary: model.summary)

                    VStack(alignment: .leading, spacing: 12) {
                        Label("이번 튜토리얼에서 비교한 것", systemImage: "square.grid.2x2.fill")
                            .font(.headline)
                            .foregroundStyle(.white)

                        VStack(alignment: .leading, spacing: 10) {
                            completionPoint("세계의 출처", symbol: "globe.asia.australia.fill")
                            completionPoint("좌표의 기준", symbol: "move.3d")
                            completionPoint("앞뒤 관계", symbol: "square.3.layers.3d")
                            completionPoint(
                                "노드와 Entity의 책임",
                                symbol: "point.3.connected.trianglepath.dotted"
                            )
                        }
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ChapterFourPalette.card, in: RoundedRectangle(cornerRadius: 22))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(.white.opacity(0.14), lineWidth: 1)
                    }
                }
                .frame(maxWidth: 620)
                .padding(.horizontal, 20)
                .padding(.top, 90)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            actionPanel
        }
        .opacity(hasAppeared ? 1 : 0)
        .scaleEffect(hasAppeared || reduceMotion ? 1 : 0.98)
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

    private var completionMark: some View {
        ZStack {
            Circle()
                .fill(ChapterFourPalette.accent.opacity(0.15))
                .frame(width: 108, height: 108)

            Circle()
                .stroke(ChapterFourPalette.accent.opacity(0.38), lineWidth: 1)
                .frame(width: 88, height: 88)

            Image(systemName: model.summary.completedRealHide ? "checkmark" : "book.closed.fill")
                .font(.system(size: 36, weight: .heavy))
                .foregroundStyle(ChapterFourPalette.accent)
        }
        .accessibilityHidden(true)
    }

    private var completionTitle: String {
        model.summary.completedRealHide ? "튜토리얼 완료" : "비교 학습 완료"
    }

    private var completionMessage: String {
        if model.summary.completedRealHide {
            return "닫힌 세계에서 현실로 이어지는 차이를 직접 확인했어."
        }
        return "네 비교 축을 살펴봤어. 실제 숨바꼭질 단계는 아직 남아 있어."
    }

    private func completionPoint(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.body.weight(.semibold))
            .foregroundStyle(ChapterFourPalette.secondaryText)
    }

    private var actionPanel: some View {
        VStack(spacing: 10) {
            Button(action: onRetryChapterThree) {
                Label("Chapter 3 다시 하기", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(ChapterFourButtonStyle(kind: .primary))
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
            .buttonStyle(ChapterFourButtonStyle(kind: .secondary))
            .accessibilityHint("모든 진행을 초기화하고 Chapter 1부터 다시 시작합니다")
        }
        .frame(maxWidth: 620)
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

#if DEBUG
struct TutorialCompletionView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            TutorialCompletionView(
                reason: .completedHide,
                retryAvailability: .available,
                onRetryChapterThree: {},
                onReset: {}
            )
            .previewDisplayName("숨바꼭질 완료")

            TutorialCompletionView(
                reason: .cameraDenied,
                retryAvailability: .unavailable(
                    reason: "카메라 권한을 허용한 뒤 다시 시도할 수 있어."
                ),
                onRetryChapterThree: {},
                onReset: {}
            )
            .previewDisplayName("우회 완료")
        }
    }
}
#endif
