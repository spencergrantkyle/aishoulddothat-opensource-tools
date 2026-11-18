import AppKit

/// One hotkey press: the captured screen context plus the question/answer turns asked against it.
@MainActor
final class Session: ObservableObject {
    enum Phase: Equatable { case idle, thinking, streaming, done, failed(String) }

    @Published var query = ""
    @Published var appName = ""
    @Published var appIcon: NSImage?
    @Published var windowTitle: String?
    @Published var thumbnail: NSImage?
    @Published var captureFailed = false
    @Published var lastQuestion: String?
    @Published var raw = ""
    @Published var phase: Phase = .idle
    @Published var footer = ""
    @Published var focusTick = 0

    var answer: Answer { Answer.parse(raw) }

    private var jpeg: Data?
    private var history: [Agent.Turn] = []
    private var captureTask: Task<Void, Never>?
    private var requestTask: Task<Void, Never>?

    func begin(app: NSRunningApplication?, windowTitle: String?, windowBounds: CGRect?) {
        cancel()
        query = ""; raw = ""; footer = ""; phase = .idle; lastQuestion = nil
        history = []; jpeg = nil; thumbnail = nil; captureFailed = false
        appName = app?.localizedName ?? "Unknown app"
        appIcon = app?.icon
        self.windowTitle = windowTitle

        let maxDimension = ConfigStore.load().maxImageDimension ?? 1280
        captureTask = Task {
            do {
                let (data, thumb) = try await Capture.screenshot(windowBounds: windowBounds,
                                                                 maxDimension: maxDimension)
                jpeg = data
                thumbnail = thumb
            } catch {
                captureFailed = true
            }
        }
        Agent.warmUp()
    }

    func cancel() {
        requestTask?.cancel()
        captureTask?.cancel()
    }

    func submit() {
        let question = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }
        guard let apiKey = ConfigStore.apiKey else {
            phase = .failed("No OpenRouter key. Add OPENROUTER_API_KEY to ~/projects/NextKey/.env, or use the menu bar icon → Set OpenRouter API Key…")
            return
        }
        requestTask?.cancel()
        lastQuestion = question
        query = ""
        raw = ""
        phase = .thinking

        let config = ConfigStore.load()
        let model = config.model ?? ConfigStore.defaultModel

        requestTask = Task {
            await captureTask?.value  // usually finished long before the user hits Return

            let isFirst = history.isEmpty
            var text = question
            if isFirst {
                text = """
                Frontmost app: \(appName)
                Window title: \(windowTitle ?? "unknown")
                \(jpeg == nil ? "(No screenshot available.)\n" : "")
                Question: \(question)
                """
            }
            history.append(.init(role: "user", text: text, jpeg: isFirst ? jpeg : nil))

            let start = Date()
            var firstToken: TimeInterval?
            do {
                for try await chunk in Agent.stream(history: history, model: model, apiKey: apiKey,
                                                    reasoningEffort: config.reasoningEffort) {
                    if firstToken == nil {
                        firstToken = Date().timeIntervalSince(start)
                        phase = .streaming
                    }
                    raw += chunk
                }
                history.append(.init(role: "assistant", text: raw, jpeg: nil))
                let total = Date().timeIntervalSince(start)
                let name = ConfigStore.models.first { $0.id == model }?.name ?? model
                footer = String(format: "%@ · %.1fs", name, total)
                phase = .done
            } catch is CancellationError {
            } catch {
                if Task.isCancelled { return }
                history.removeLast()
                phase = .failed(error.localizedDescription)
            }
        }
    }
}
