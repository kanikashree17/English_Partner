import SwiftUI
import AVFoundation
import Combine

// ============================================================
// MARK: - APP CONFIGURATION
// ============================================================

enum AppConfig {
    // IMPORTANT: Put your Gemini API key here for testing.
    // Do NOT ship a real API key inside a production iOS app.
    static let apiKey = "AQ.Ab8RN6J0bouLAlgPhTVDdLC8y5PpHkpAW2BIlWPGgDEPsqrArw"

    // Fast-first model order.
    // Flash-Lite is optimized for low latency and high-throughput tasks.
    static let models = [
        "gemini-3.5-flash-lite",
        "gemini-3.6-flash",
        "gemini-3.5-flash",
        "gemini-3.7-flash",
        "gemini-3.8-flash"
    ]

    static func endpoint(for model: String) -> URL? {
        URL(string:
            "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
        )
    }
}

// ============================================================
// MARK: - APP ENTRY
// ============================================================

@main
struct EnglishPartnerApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
}

// ============================================================
// MARK: - MAIN TAB VIEW
// ============================================================

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            if selectedTab == 0 {
                ChatView()
            } else {
                PracticeView()
            }

            BottomModePicker(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

struct BottomModePicker: View {
    @Binding var selectedTab: Int

    var body: some View {
        HStack(spacing: 0) {
            modeButton(
                title: "Partner",
                icon: "bubble.left.and.bubble.right.fill",
                index: 0
            )

            modeButton(
                title: "Practice",
                icon: "mic.fill",
                index: 1
            )
        }
        .padding(5)
        .background(Color(.systemBackground))
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.08), radius: 18, y: 4)
        .padding(.horizontal, 110)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private func modeButton(title: String, icon: String, index: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = index
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 25, weight: .medium))
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(selectedTab == index ? Color.blue : Color.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .background(
                selectedTab == index
                ? Color(.systemGray6)
                : Color.clear
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// ============================================================
// MARK: - CHAT MODELS
// ============================================================

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
}

struct ChatAIResponse: Codable {
    let reply: String
    let correction: String
}

// ============================================================
// MARK: - CHAT VIEW MODEL
// ============================================================

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = [
        ChatMessage(
            text: "Hi! I'm your English Partner 😊\n\nTalk to me naturally in English. I'll help you practice.",
            isUser: false
        )
    ]

    @Published var input = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var conversationHistory: [[String: Any]] = []

    func sendMessage() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isLoading else { return }

        messages.append(ChatMessage(text: text, isUser: true))
        input = ""
        errorMessage = nil
        isLoading = true

        Task {
            do {
                let result = try await GeminiService.shared.chat(
                    message: text,
                    history: conversationHistory
                )

                messages.append(
                    ChatMessage(text: result.reply, isUser: false)
                )

                if !result.correction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    messages.append(
                        ChatMessage(
                            text: "✨ Better English:\n\(result.correction)",
                            isUser: false
                        )
                    )
                }

                conversationHistory.append([
                    "role": "user",
                    "text": text
                ])

                conversationHistory.append([
                    "role": "model",
                    "text": result.reply
                ])
            } catch {
                errorMessage = error.localizedDescription
            }

            isLoading = false
        }
    }
}

// ============================================================
// MARK: - CHAT VIEW
// ============================================================

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 14) {
                        Color.clear
                            .frame(height: 1)
                            .id("top")

                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }

                        if viewModel.isLoading {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("English Partner is thinking...")
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal)
                        }

                        if let error = viewModel.errorMessage {
                            VStack(spacing: 8) {
                                Text(error)
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                                    .multilineTextAlignment(.center)

                                Button("Try Again") {
                                    viewModel.errorMessage = nil
                                }
                                .font(.footnote.weight(.semibold))
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.horizontal, 34)
                    .padding(.top, 24)
                    .padding(.bottom, 16)
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    if let last = viewModel.messages.last {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            HStack(alignment: .bottom, spacing: 10) {
                TextField(
                    "Talk to me in English...",
                    text: $viewModel.input,
                    axis: .vertical
                )
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...5)

                Button {
                    viewModel.sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(
                            viewModel.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading
                            ? Color(.systemGray3)
                            : .blue
                        )
                }
                .disabled(
                    viewModel.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    viewModel.isLoading
                )
            }
            .padding(.horizontal, 34)
            .padding(.vertical, 12)
        }
        .safeAreaInset(edge: .top) {
            HStack {
                Text("English Partner")
                    .font(.system(size: 36, weight: .bold))
                Spacer()
            }
            .padding(.horizontal, 34)
            .padding(.top, 18)
            .padding(.bottom, 14)
            .background(Color(.systemBackground))
        }
    }
}

// ============================================================
// MARK: - MESSAGE BUBBLE
// ============================================================

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.isUser {
                Spacer(minLength: 60)
            }

            Text(message.text)
                .font(.system(size: 18))
                .foregroundStyle(message.isUser ? .white : .primary)
                .padding(.horizontal, 20)
                .padding(.vertical, 15)
                .background(
                    message.isUser
                    ? Color.blue
                    : Color(.secondarySystemBackground)
                )
                .clipShape(RoundedRectangle(cornerRadius: 22))

            if !message.isUser {
                Spacer(minLength: 20)
            }
        }
    }
}

// ============================================================
// MARK: - DIFFICULTY
// ============================================================

enum Difficulty: String, CaseIterable, Identifiable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .low: return "Easy words & sentences"
        case .medium: return "Moderate words & sentences"
        case .high: return "Challenging words & sentences"
        }
    }
}

enum QuestionType: String {
    case word
    case sentence
}

struct PracticeQuestion: Identifiable {
    let id = UUID()
    let text: String
    let difficulty: Difficulty
    let type: QuestionType
}

// ============================================================
// MARK: - QUESTION BANK
// ============================================================

enum QuestionBank {
    static let low: [PracticeQuestion] = [
        PracticeQuestion(text: "apple", difficulty: .low, type: .word),
        PracticeQuestion(text: "water", difficulty: .low, type: .word),
        PracticeQuestion(text: "happy", difficulty: .low, type: .word),
        PracticeQuestion(text: "friend", difficulty: .low, type: .word),
        PracticeQuestion(text: "morning", difficulty: .low, type: .word),
        PracticeQuestion(text: "I like coffee.", difficulty: .low, type: .sentence),
        PracticeQuestion(text: "Good morning.", difficulty: .low, type: .sentence),
        PracticeQuestion(text: "How are you?", difficulty: .low, type: .sentence),
        PracticeQuestion(text: "I am happy today.", difficulty: .low, type: .sentence),
        PracticeQuestion(text: "This is my book.", difficulty: .low, type: .sentence)
    ]

    static let medium: [PracticeQuestion] = [
        PracticeQuestion(text: "adventure", difficulty: .medium, type: .word),
        PracticeQuestion(text: "comfortable", difficulty: .medium, type: .word),
        PracticeQuestion(text: "environment", difficulty: .medium, type: .word),
        PracticeQuestion(text: "experience", difficulty: .medium, type: .word),
        PracticeQuestion(text: "conversation", difficulty: .medium, type: .word),
        PracticeQuestion(text: "opportunity", difficulty: .medium, type: .word),
        PracticeQuestion(text: "I enjoy learning new things.", difficulty: .medium, type: .sentence),
        PracticeQuestion(text: "I usually wake up early.", difficulty: .medium, type: .sentence),
        PracticeQuestion(text: "I want to improve my English.", difficulty: .medium, type: .sentence),
        PracticeQuestion(text: "Technology makes our lives easier.", difficulty: .medium, type: .sentence)
    ]

    static let high: [PracticeQuestion] = [
        PracticeQuestion(text: "entrepreneurship", difficulty: .high, type: .word),
        PracticeQuestion(text: "pronunciation", difficulty: .high, type: .word),
        PracticeQuestion(text: "extraordinary", difficulty: .high, type: .word),
        PracticeQuestion(text: "responsibility", difficulty: .high, type: .word),
        PracticeQuestion(text: "communication", difficulty: .high, type: .word),
        PracticeQuestion(text: "misunderstanding", difficulty: .high, type: .word),
        PracticeQuestion(text: "She thoroughly considered every possibility.", difficulty: .high, type: .sentence),
        PracticeQuestion(text: "Clear communication prevents unnecessary misunderstandings.", difficulty: .high, type: .sentence),
        PracticeQuestion(text: "I would have handled the situation differently.", difficulty: .high, type: .sentence),
        PracticeQuestion(text: "The extraordinary opportunity required considerable preparation.", difficulty: .high, type: .sentence)
    ]

    static func questions(for difficulty: Difficulty) -> [PracticeQuestion] {
        switch difficulty {
        case .low: return low
        case .medium: return medium
        case .high: return high
        }
    }
}

// ============================================================
// MARK: - PRONUNCIATION RESULT
// ============================================================

struct PronunciationResult: Codable {
    let correct: Bool
    let score: Int
    let heard: String
    let feedback: String
}

// ============================================================
// MARK: - AUDIO RECORDER
// ============================================================

@MainActor
final class AudioRecorderManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var permissionDenied = false

    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?

    func requestPermissionAndStart() async {
        let granted = await AVAudioApplication.requestRecordPermission()

        guard granted else {
            permissionDenied = true
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("english-practice-\(UUID().uuidString).m4a")

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.prepareToRecord()
            recorder?.record()
            recordingURL = url
            isRecording = true
        } catch {
            isRecording = false
        }
    }

    func stopRecording() -> Data? {
        recorder?.stop()
        isRecording = false

        guard let url = recordingURL else { return nil }

        defer {
            try? FileManager.default.removeItem(at: url)
            recordingURL = nil
        }

        return try? Data(contentsOf: url)
    }
}

// ============================================================
// MARK: - SPEECH PLAYER
// ============================================================

final class SpeechPlayer {
    static let shared = SpeechPlayer()
    private let synthesizer = AVSpeechSynthesizer()

    private init() {}

    func speak(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.43
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        synthesizer.speak(utterance)
    }
}

// ============================================================
// MARK: - PRACTICE VIEW
// ============================================================

struct PracticeView: View {
    @StateObject private var recorder = AudioRecorderManager()

    @State private var difficulty: Difficulty = .low
    @State private var currentQuestion: PracticeQuestion
    @State private var result: PronunciationResult?
    @State private var isChecking = false
    @State private var errorMessage: String?

    init() {
        let first = QuestionBank.questions(for: .low).randomElement()!
        _currentQuestion = State(initialValue: first)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    HStack {
                        Text("Pronunciation Practice")
                            .font(.system(size: 34, weight: .bold))
                        Spacer()
                    }

                    difficultyPicker

                    questionCard

                    if let result {
                        PronunciationResultCard(
                            result: result,
                            onTryAgain: tryAgain,
                            onNext: nextQuestion
                        )
                    } else {
                        recordButton
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 34)
                .padding(.top, 24)
                .padding(.bottom, 24)
            }
        }
        .safeAreaInset(edge: .top) {
            Color.clear.frame(height: 0)
        }
        .alert("Microphone Access Needed", isPresented: $recorder.permissionDenied) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please enable microphone access in Settings → English Partner → Microphone.")
        }
    }

    private var difficultyPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Difficulty")
                .font(.headline)

            Picker("Difficulty", selection: $difficulty) {
                ForEach(Difficulty.allCases) { level in
                    Text(level.rawValue).tag(level)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: difficulty) { _, newValue in
                let questions = QuestionBank.questions(for: newValue)
                if let question = questions.randomElement() {
                    currentQuestion = question
                }
                result = nil
                errorMessage = nil
            }
        }
    }

    private var questionCard: some View {
        VStack(spacing: 18) {
            Text(currentQuestion.type == .word ? "WORD" : "SENTENCE")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            Text(currentQuestion.text)
                .font(.system(size: 34, weight: .bold))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)

            Button {
                SpeechPlayer.shared.speak(currentQuestion.text)
            } label: {
                Label("Listen", systemImage: "speaker.wave.2.fill")
                    .font(.headline)
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(30)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 28))
    }

    private var recordButton: some View {
        VStack(spacing: 12) {
            Button {
                if recorder.isRecording {
                    submitRecording()
                } else {
                    startRecording()
                }
            } label: {
                Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 78, height: 78)
                    .background(recorder.isRecording ? Color.red : Color.blue)
                    .clipShape(Circle())
            }
            .disabled(isChecking)

            Text(
                isChecking
                ? "Checking pronunciation..."
                : recorder.isRecording
                ? "Tap to stop"
                : "Tap to speak"
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.top, 10)
    }

    private func startRecording() {
        errorMessage = nil
        Task {
            await recorder.requestPermissionAndStart()
        }
    }

    private func submitRecording() {
        guard let audioData = recorder.stopRecording() else {
            errorMessage = AppError.recordingFailed.localizedDescription
            return
        }

        isChecking = true
        errorMessage = nil

        Task {
            do {
                result = try await GeminiService.shared.checkPronunciation(
                    target: currentQuestion.text,
                    audioData: audioData
                )
            } catch {
                errorMessage = error.localizedDescription
            }
            isChecking = false
        }
    }

    private func tryAgain() {
        result = nil
        errorMessage = nil
    }

    private func nextQuestion() {
        let questions = QuestionBank.questions(for: difficulty)
        guard !questions.isEmpty else { return }

        var next = questions.randomElement()!
        while questions.count > 1 && next.text == currentQuestion.text {
            next = questions.randomElement()!
        }

        currentQuestion = next
        result = nil
        errorMessage = nil
    }
}

// ============================================================
// MARK: - RESULT CARD
// ============================================================

struct PronunciationResultCard: View {
    let result: PronunciationResult
    let onTryAgain: () -> Void
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: result.correct ? "checkmark.circle.fill" : "arrow.clockwise.circle.fill")
                .font(.system(size: 58))
                .foregroundStyle(result.correct ? .green : .orange)

            Text(result.correct ? "Correct!" : "Needs Practice")
                .font(.title2.bold())

            Text("\(max(0, min(result.score, 100)))%")
                .font(.system(size: 48, weight: .bold))

            VStack(alignment: .leading, spacing: 8) {
                Text("What AI Heard")
                    .font(.headline)
                Text(result.heard)
                    .foregroundStyle(.secondary)

                Text("AI Feedback")
                    .font(.headline)
                    .padding(.top, 8)
                Text(result.feedback)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                Button("Try Again", action: onTryAgain)
                    .buttonStyle(.bordered)

                if result.correct {
                    Button("Next Question", action: onNext)
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 28))
    }
}

// ============================================================
// MARK: - GEMINI SERVICE
// ============================================================

final class GeminiService {
    static let shared = GeminiService()
    private init() {}

    // --------------------------------------------------------
    // CHAT
    // --------------------------------------------------------

    func chat(
        message: String,
        history: [[String: Any]]
    ) async throws -> ChatAIResponse {
        let systemPrompt = """
        You are English Partner, a friendly English-speaking conversation partner.

        Help the user improve everyday English, grammar, vocabulary, natural sentence formation,
        confidence, and communication skills.

        Have a natural conversation. Do not make every response feel like a classroom lesson.
        If the user's English is correct, continue naturally.
        If there is a meaningful grammar or wording mistake, gently provide a better sentence.
        Keep corrections short.

        Return ONLY valid JSON:
        {
          "reply": "natural conversational response",
          "correction": "better sentence, or empty string if no correction is needed"
        }
        """

        var contents: [[String: Any]] = []

        for item in history {
            guard
                let role = item["role"] as? String,
                let text = item["text"] as? String
            else { continue }

            contents.append([
                "role": role,
                "parts": [["text": text]]
            ])
        }

        contents.append([
            "role": "user",
            "parts": [["text": message]]
        ])

        let body: [String: Any] = [
            "systemInstruction": [
                "parts": [["text": systemPrompt]]
            ],
            "contents": contents,
            "generationConfig": [
                "responseMimeType": "application/json",
                "maxOutputTokens": 300
            ]
        ]

        let data = try await performRequest(body: body)
        let text = try extractText(from: data)
        let jsonText = cleanJSON(text)

        guard let jsonData = jsonText.data(using: .utf8) else {
            throw AppError.invalidResponse
        }

        do {
            return try JSONDecoder().decode(ChatAIResponse.self, from: jsonData)
        } catch {
            throw AppError.invalidAIResponse(jsonText)
        }
    }

    // --------------------------------------------------------
    // PRONUNCIATION
    // --------------------------------------------------------

    func checkPronunciation(
        target: String,
        audioData: Data
    ) async throws -> PronunciationResult {
        let base64Audio = audioData.base64EncodedString()

        let prompt = """
        You are an English pronunciation evaluator.

        TARGET TEXT:
        "\(target)"

        The user recorded themselves saying the target text.
        Analyze the ACTUAL AUDIO.

        Determine:
        1. What the user appears to have said.
        2. Whether pronunciation is acceptable and understandable.
        3. A pronunciation score from 0 to 100.
        4. Short, useful feedback.

        Consider consonant sounds, vowel sounds, syllables, word stress, sentence rhythm,
        missing sounds, added sounds, unclear sounds, and whether the user actually said the target.

        Do not mark the answer correct merely because the transcript could be interpreted as the target.
        For a word, evaluate pronunciation of the word.
        For a sentence, evaluate overall pronunciation, clarity, rhythm, and intelligibility.

        Use a fair standard for an English learner.
        Set correct to true when pronunciation is clearly acceptable and understandable.
        Set correct to false when there is a noticeable pronunciation problem or the target was not pronounced.

        Return ONLY valid JSON:
        {
          "correct": true,
          "score": 90,
          "heard": "what the AI heard",
          "feedback": "short useful feedback"
        }
        """

        let body: [String: Any] = [
            "contents": [[
                "role": "user",
                "parts": [
                    ["text": prompt],
                    [
                        "inlineData": [
                            "mimeType": "audio/mp4",
                            "data": base64Audio
                        ]
                    ]
                ]
            ]],
            "generationConfig": [
                "responseMimeType": "application/json",
                "maxOutputTokens": 400
            ]
        ]

        let data = try await performRequest(body: body)
        let text = try extractText(from: data)
        let jsonText = cleanJSON(text)

        guard let jsonData = jsonText.data(using: .utf8) else {
            throw AppError.invalidResponse
        }

        do {
            return try JSONDecoder().decode(PronunciationResult.self, from: jsonData)
        } catch {
            throw AppError.invalidAIResponse(jsonText)
        }
    }

    // --------------------------------------------------------
    // HTTP REQUEST + MODEL FALLBACK
    // --------------------------------------------------------

    private func performRequest(
        body: [String: Any]
    ) async throws -> Data {
        guard !AppConfig.apiKey.isEmpty,
              AppConfig.apiKey != "YOUR_GEMINI_API_KEY"
        else {
            throw AppError.missingAPIKey
        }

        var lastError: Error?

        for model in AppConfig.models {
            guard let url = AppConfig.endpoint(for: model) else {
                continue
            }

            var requestBody = body

            // Fastest settings for each model.
            // Flash-Lite and 3.6 support MINIMAL; 3.7/3.8 use LOW.
            if var generationConfig = requestBody["generationConfig"] as? [String: Any] {
                let thinkingLevel: String

                switch model {
                case "gemini-3.5-flash-lite", "gemini-3.6-flash", "gemini-3.5-flash":
                    thinkingLevel = "minimal"
                default:
                    thinkingLevel = "low"
                }

                generationConfig["thinkingConfig"] = [
                    "thinkingLevel": thinkingLevel
                ]

                requestBody["generationConfig"] = generationConfig
            }

            do {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.timeoutInterval = 20
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AppError.invalidResponse
                }

                if (200...299).contains(httpResponse.statusCode) {
                    return data
                }

                let serverMessage = extractServerMessage(from: data)
                let code = httpResponse.statusCode

                if [408, 429, 500, 502, 503, 504].contains(code) {
                    lastError = AppError.serverError(
                        code,
                        "\(serverMessage) [model: \(model)]"
                    )
                    continue
                }

                throw AppError.serverError(
                    code,
                    "\(serverMessage) [model: \(model)]"
                )
            } catch {
                lastError = error

                if let urlError = error as? URLError {
                    switch urlError.code {
                    case .timedOut, .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet:
                        continue
                    default:
                        throw error
                    }
                }

                if let appError = error as? AppError {
                    switch appError {
                    case .serverError(let code, _):
                        if [408, 429, 500, 502, 503, 504].contains(code) {
                            continue
                        }
                    default:
                        break
                    }
                }

                throw error
            }
        }

        throw lastError ?? AppError.invalidResponse
    }

    // --------------------------------------------------------
    // RESPONSE PARSING
    // --------------------------------------------------------

    private func extractText(from data: Data) throws -> String {
        let object = try JSONSerialization.jsonObject(with: data)

        guard let root = object as? [String: Any] else {
            throw AppError.invalidResponse
        }

        if let error = root["error"] as? [String: Any] {
            let message = error["message"] as? String ?? "Unknown Gemini error."
            let code = error["code"] as? Int ?? 500
            throw AppError.serverError(code, message)
        }

        guard let candidates = root["candidates"] as? [[String: Any]] else {
            throw AppError.invalidAIResponse("Unknown Gemini response.")
        }

        for candidate in candidates {
            if let content = candidate["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]] {
                let texts = parts.compactMap { $0["text"] as? String }
                if !texts.isEmpty {
                    return texts.joined()
                }
            }
        }

        throw AppError.invalidResponse
    }

    private func extractServerMessage(from data: Data) -> String {
        guard
            let object = try? JSONSerialization.jsonObject(with: data),
            let root = object as? [String: Any],
            let error = root["error"] as? [String: Any]
        else {
            return String(data: data, encoding: .utf8) ?? "Unknown server error."
        }

        return error["message"] as? String ?? "Unknown Gemini error."
    }

    private func cleanJSON(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if result.hasPrefix("```") {
            result = result
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let first = result.firstIndex(of: "{"),
           let last = result.lastIndex(of: "}") {
            result = String(result[first...last])
        }

        return result
    }
}

// ============================================================
// MARK: - APP ERRORS
// ============================================================

enum AppError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case invalidAIResponse(String)
    case serverError(Int, String)
    case recordingFailed

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Gemini API key is missing. Put your key in AppConfig.apiKey."

        case .invalidResponse:
            return "Gemini returned an unexpected response."

        case .invalidAIResponse(let response):
            return "Gemini returned an unexpected result:\n\n\(response)"

        case .serverError(let code, let message):
            return "Gemini API error \(code):\n\n\(message)"

        case .recordingFailed:
            return "The recording could not be read. Please try again."
        }
    }
}
