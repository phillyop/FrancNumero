import SwiftUI

/// Runs one page from start to finish: playing, then (if three answers get
/// crossed out) a torn page and a correction, then the mark.
struct LessonFlowView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let request: LessonRequest

    private enum Stage { case playing, torn, correction, result, testResult }

    @State private var engine = LessonEngine(exercises: [], mode: .standard)
    @State private var stage: Stage = .playing
    @State private var summary: LessonSummary?
    @State private var testSummary: TestOutSummary?
    @State private var failedOnPage: [Int] = []
    @State private var started = false

    var body: some View {
        ZStack {
            PaperBackground()
            switch stage {
            case .playing:
                LessonPlayView(engine: $engine, onClose: { dismiss() })
            case .torn:
                TornPageView(onContinue: { stage = .correction })
            case .correction:
                CorrectionView(
                    numbers: failedOnPage,
                    title: "The correction",
                    subtitle: "Read these through once, then start again on a clean page. They’ll come back first.",
                    buttonTitle: "Start a clean page",
                    onContinue: startCleanPage
                )
            case .result:
                if let summary {
                    ResultView(summary: summary, onDone: { dismiss() })
                }
            case .testResult:
                if let testSummary {
                    TestOutResultView(summary: testSummary, onDone: { dismiss() })
                }
            }
        }
        .onAppear {
            if !started {
                started = true
                engine = store.makeLesson(for: request)
            }
        }
        .onChange(of: engine.results.count) { _, _ in
            if let last = engine.results.last { store.record(last) }
        }
        .onChange(of: engine.step) { _, newStep in
            handle(newStep)
        }
    }

    private func handle(_ step: LessonEngine.Step) {
        switch step {
        case .torn:
            failedOnPage = engine.failedNumbers
            store.registerTear()
            stage = .torn
        case .finished:
            if engine.exercises.isEmpty {
                dismiss()
            } else if let chapter = request.testOutChapter {
                testSummary = store.completeTestOut(engine, chapterID: chapter)
                stage = .testResult
            } else {
                summary = store.completeLesson(engine)
                stage = .result
            }
        default:
            break
        }
    }

    private func startCleanPage() {
        engine = store.makeLesson(for: LessonRequest(chapter: request.chapter, forced: failedOnPage))
        stage = .playing
    }
}
