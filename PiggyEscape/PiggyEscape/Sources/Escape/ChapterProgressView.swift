import SwiftUI

struct ChapterProgressView: View {
    let chapter: TutorialChapter

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...4, id: \.self) { number in
                Capsule()
                    .fill(number <= chapterNumber ? Color.yellow : Color.white.opacity(0.34))
                    .frame(height: 5)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: 520)
        .background(.black.opacity(0.30), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("4개 챕터 중 \(chapterNumber)번째, \(chapterTitle)")
    }

    private var chapterNumber: Int {
        switch chapter {
        case .closedWorld: 1
        case .openingReality: 2
        case .realHideAndSeek: 3
        case .comparison: 4
        }
    }

    private var chapterTitle: String {
        switch chapter {
        case .closedWorld: "닫힌 세계"
        case .openingReality: "현실 열기"
        case .realHideAndSeek: "현실 숨바꼭질"
        case .comparison: "두 세계 비교"
        }
    }
}
