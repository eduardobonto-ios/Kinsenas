import SwiftUI
import Combine

// MARK: - Chat Message

struct ChatMessage: Identifiable, Equatable {
    enum Role { case user, assistant }
    let id: UUID
    let role: Role
    let text: String
    init(role: Role, text: String)           { id = UUID(); self.role = role; self.text = text }
    init(id: UUID, role: Role, text: String) { self.id = id; self.role = role; self.text = text }
}

// MARK: - View Model

final class BudgetChatbotViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var input: String = ""
    @Published private(set) var isSending   = false
    @Published private(set) var modelState  = ModelLoadState.notLoaded

    enum ModelLoadState: Equatable {
        case notLoaded
        case loading
        case ready
        case failed(String)
    }

    private let getRows:            () -> [BudgetRow]
    private let getRemaining15:     () -> Double
    private let getRemaining30:     () -> Double
    private let getFirstCutoffDay:  () -> Int
    private let getSecondCutoffDay: () -> Int

    init(getRows: @escaping () -> [BudgetRow],
         getRemaining15: @escaping () -> Double,
         getRemaining30: @escaping () -> Double,
         getFirstCutoffDay: @escaping () -> Int,
         getSecondCutoffDay: @escaping () -> Int) {
        self.getRows            = getRows
        self.getRemaining15     = getRemaining15
        self.getRemaining30     = getRemaining30
        self.getFirstCutoffDay  = getFirstCutoffDay
        self.getSecondCutoffDay = getSecondCutoffDay

        messages = [ChatMessage(role: .assistant, text: """
        Hi! I'm Kinsenas AI 🤖
        Ask me about your budget, what to cut, savings goals, or if you can spend.

        Example: "Which item should I remove to save more?"
        """)]

        // Pre-load model as soon as chat opens
        Task { await warmUpModel() }
    }

    // MARK: - Model warm-up

    @MainActor
    func warmUpModel() async {
        guard modelState == .notLoaded else { return }
        modelState = .loading
        do {
            try await Task.detached(priority: .userInitiated) {
                try await LlamaAIService.shared.loadModelIfNeeded()
            }.value
            modelState = .ready
        } catch {
            modelState = .failed(error.localizedDescription)
        }
    }

    // MARK: - Send

    func send() {
        let t = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, modelState == .ready else { return }
        input = ""
        dispatch(t)
    }

    func sendPreset(_ msg: String) {
        let t = msg.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, modelState == .ready else { return }
        dispatch(t)
    }

    private func dispatch(_ text: String) {
        DispatchQueue.main.async {
            self.messages.append(ChatMessage(role: .user, text: text))
            let pid = UUID()
            self.messages.append(ChatMessage(id: pid, role: .assistant, text: "…"))
            self.isSending = true
            Task { await self.callLlama(message: text, placeholderID: pid) }
        }
    }

    private func replacePlaceholder(id: UUID, with text: String) {
        DispatchQueue.main.async {
            if let i = self.messages.firstIndex(where: { $0.id == id }) {
                self.messages[i] = ChatMessage(id: id, role: .assistant, text: text)
            }
            self.isSending = false
        }
    }

    // MARK: - No-hallucination guard (unchanged from Groq version)

    private func handleDeterministicResponse(ctx: BudgetContext) -> String? {
        if ctx.intent == "cut" && !ctx.rows.contains(where: { !$0.isEssential }) {
            return """
            You currently don't have any non-essential expenses to cut.
            All your listed items are essential (loans, housing, etc.).

            To save more:
            • Avoid adding new unnecessary expenses
            • Increase income if possible
            • Adjust savings gradually
            """
        }
        return nil
    }

    // MARK: - On-device Llama call (no network)

    private func callLlama(message: String, placeholderID: UUID) async {
        let ctx = BudgetContext(
            rows:            getRows(),
            remaining15:     getRemaining15(),
            remaining30:     getRemaining30(),
            firstCutoffDay:  getFirstCutoffDay(),
            secondCutoffDay: getSecondCutoffDay(),
            userMessage:     message
        )

        if let safeReply = handleDeterministicResponse(ctx: ctx) {
            replacePlaceholder(id: placeholderID, with: safeReply)
            return
        }

        // Run inference on background thread — it's synchronous and CPU/GPU intensive
        do {
            let reply = try await Task.detached(priority: .userInitiated) {
                try await LlamaAIService.ask(
                    systemPrompt: ctx.systemPrompt,
                    userPrompt:   ctx.userPrompt
                )
            }.value
            replacePlaceholder(id: placeholderID, with: reply)
        } catch {
            replacePlaceholder(id: placeholderID, with: "AI error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Model Loading Overlay

private struct ModelLoadingView: View {
    let state: BudgetChatbotViewModel.ModelLoadState
    let onRetry: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 20) {
                switch state {
                case .loading:
                    VStack(spacing: 14) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(1.5)
                            .tint(.orange)
                        Text("Loading AI model…")
                            .font(.system(.headline, design: .rounded))
                            .foregroundColor(.white)
                        Text("First launch takes ~5 seconds")
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                    }
                case .failed(let msg):
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40)).foregroundColor(.orange)
                        Text("Could not load AI model")
                            .font(.system(.headline, design: .rounded)).foregroundColor(.white)
                        Text(msg)
                            .font(.caption).foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center).padding(.horizontal, 24)
                        Button("Retry") { onRetry() }
                            .padding(.horizontal, 28).padding(.vertical, 10)
                            .background(Capsule().fill(Color.orange))
                            .foregroundColor(.white)
                            .font(.system(.body, design: .rounded).weight(.semibold))
                    }
                default:
                    EmptyView()
                }
            }
            .padding(32)
            .background(RoundedRectangle(cornerRadius: 20).fill(Color(white: 0.12)))
            .padding(40)
        }
    }
}

// MARK: - Robot View

private struct RobotView: View {
    @Binding var isTalking: Bool
    @Binding var isJumping: Bool
    @State private var blink  = false
    @State private var bounce = false
    @State private var hue: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .fill(AngularGradient(
                    gradient: Gradient(colors: [.orange, .yellow, .orange.opacity(0.9), .orange]),
                    center: .center))
                .shadow(color: .orange.opacity(0.3), radius: 12, x: 0, y: 6)
            HStack(spacing: 12) {
                Capsule().fill(Color.white).frame(width: 16, height: blink ? 2 : 8)
                Capsule().fill(Color.white).frame(width: 16, height: blink ? 2 : 8)
            }.offset(y: -6)
            Capsule().fill(Color.white.opacity(0.9))
                .frame(width: isTalking ? 18 : 10, height: isTalking ? 6 : 2)
                .animation(.easeInOut(duration: 0.2), value: isTalking)
                .offset(y: 10)
        }
        .frame(width: 48, height: 48)
        .rotationEffect(.degrees(bounce ? -4 : 4))
        .hueRotation(.degrees(hue))
        .offset(y: isJumping ? -10 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: isJumping)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.12).repeatForever(autoreverses: true)) { blink.toggle() }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true))  { bounce.toggle() }
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false))      { hue = 360 }
        }
    }
}

// MARK: - Main Chat View

struct BudgetChatbotView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: BudgetChatbotViewModel
    @State private var robotTalking = false
    @State private var robotJumping = false

    init(getRows: @escaping () -> [BudgetRow],
         getRemaining15: @escaping () -> Double,
         getRemaining30: @escaping () -> Double,
         getFirstCutoffDay: @escaping () -> Int,
         getSecondCutoffDay: @escaping () -> Int) {
        _vm = StateObject(wrappedValue: BudgetChatbotViewModel(
            getRows:            getRows,
            getRemaining15:     getRemaining15,
            getRemaining30:     getRemaining30,
            getFirstCutoffDay:  getFirstCutoffDay,
            getSecondCutoffDay: getSecondCutoffDay))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {

                    // ── Header ─────────────────────────────────────
                    HStack {
                        RobotView(isTalking: $robotTalking, isJumping: $robotJumping)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Kinsenas AI")
                                .font(.system(.title3, design: .rounded).weight(.bold))
                                .foregroundStyle(.orange)
                            // Show model status in header
                            modelStatusBadge
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // ── Chat list ───────────────────────────────────
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 12) {
                                ForEach(vm.messages) { msg in
                                    messageBubble(msg).id(msg.id)
                                }
                            }.padding()
                        }
                        .onChange(of: vm.messages) { _ in
                            if let last = vm.messages.last {
                                withAnimation(.easeInOut) { proxy.scrollTo(last.id, anchor: .bottom) }
                                last.role == .assistant ? speak() : jump()
                            }
                        }
                    }

                    // ── Preset buttons ──────────────────────────────
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            // Removed: "Which item should I cut to save more?"
                            presetBtn("Can I still spend 2000 this week?")
                            presetBtn("Boost my savings strategy")
                            // Removed: "Should I invest right now?"
                        }
                        .padding(.horizontal).padding(.vertical, 6)
                    }

                    Divider()

                    // ── Input bar ───────────────────────────────────
                    HStack(spacing: 8) {
                        TextField("Ask about your budget...", text: $vm.input)
                            .textFieldStyle(.roundedBorder)
                            .submitLabel(.send)
                            .onSubmit { vm.send(); jump() }
                            .disabled(vm.modelState != .ready)

                        Button { vm.send(); jump() } label: {
                            Image(systemName: "paperplane.fill")
                                .foregroundStyle(.white).padding(10)
                                .background(Circle().fill(
                                    LinearGradient(colors: [.orange, .yellow],
                                                   startPoint: .topLeading,
                                                   endPoint: .bottomTrailing)))
                        }
                        .disabled(vm.input.isEmpty || vm.isSending || vm.modelState != .ready)
                    }
                    .font(.system(.body, design: .rounded))
                    .padding()
                    .background(.ultraThinMaterial)
                }

                // ── Model loading / error overlay ───────────────────
                if vm.modelState == .loading || vm.modelState == .failed("") {
                    ModelLoadingView(state: vm.modelState) {
                        Task { await vm.warmUpModel() }
                    }
                }
                // Handle failed state with message
                if case .failed(_) = vm.modelState {
                    ModelLoadingView(state: vm.modelState) {
                        Task { await vm.warmUpModel() }
                    }
                }
            }
            .navigationTitle("AI Budget Chat")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 0) }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    // MARK: - Model status badge

    @ViewBuilder
    private var modelStatusBadge: some View {
        switch vm.modelState {
        case .notLoaded:
            Text("Initializing…")
                .font(.system(size: 10, design: .rounded))
                .foregroundColor(.secondary)
        case .loading:
            HStack(spacing: 4) {
                ProgressView().scaleEffect(0.6).tint(.orange)
                Text("Loading model…")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(.orange)
            }
        case .ready:
            HStack(spacing: 4) {
                Circle().fill(Color.green).frame(width: 6, height: 6)
                Text("On-device AI • Offline")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(.green)
            }
        case .failed:
            Text("⚠️ Model failed — tap retry")
                .font(.system(size: 10, design: .rounded))
                .foregroundColor(.red)
        }
    }

    // MARK: - Helpers

    private func presetBtn(_ text: String) -> some View {
        Button { vm.sendPreset(text); jump() } label: {
            Text(text).font(.caption)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Capsule().fill(Color.orange.opacity(
                    vm.modelState == .ready ? 0.15 : 0.07)))
        }
        .disabled(vm.modelState != .ready)
    }

    private func speak() {
        robotTalking = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { robotTalking = false }
    }
    private func jump() {
        robotJumping = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { robotJumping = false }
    }

    private func messageBubble(_ msg: ChatMessage) -> some View {
        let isUser = msg.role == .user
        return HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 32) }
            Text(msg.text)
                .font(.system(.body, design: .rounded))
                .foregroundColor(isUser ? .orange : .white)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isUser
                              ? LinearGradient(colors: [.orange.opacity(0.25), .orange.opacity(0.15)],
                                               startPoint: .top, endPoint: .bottom)
                              : LinearGradient(colors: [.orange.opacity(0.95), .yellow.opacity(0.9)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing))
                        .shadow(color: .orange.opacity(0.25), radius: isUser ? 2 : 6,
                                x: 0, y: isUser ? 1 : 3)
                )
                .overlay(RoundedRectangle(cornerRadius: 16)
                    .stroke(isUser ? Color.orange.opacity(0.2) : Color.white.opacity(0.15), lineWidth: 1))
                .overlay(alignment: .leading) {
                    if !isUser {
                        Circle().fill(Color.white.opacity(0.8))
                            .frame(width: 6, height: 6).offset(x: -8, y: -8)
                            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                                       value: vm.messages.count)
                    }
                }
                .hueRotation(.degrees(isUser ? 0 : Double(
                    (vm.messages.firstIndex(where: { $0.id == msg.id }) ?? 0) * 6 % 360)))
                .frame(maxWidth: UIScreen.main.bounds.width * 0.72,
                       alignment: isUser ? .trailing : .leading)
            if !isUser { Spacer(minLength: 32) }
        }
        .transition(.asymmetric(
            insertion: .move(edge: isUser ? .trailing : .leading).combined(with: .opacity),
            removal: .opacity))
    }
}
