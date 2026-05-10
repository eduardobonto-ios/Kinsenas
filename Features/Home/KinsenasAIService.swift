import Foundation
import LlamaSwift
import llama

// MARK: - Model file name
// Must match exactly the filename you dragged into Xcode



// MARK: - LlamaAIService  (same interface as GroqAIService — drop-in replacement)

actor LlamaAIService {
    private let kModelFilename = "Llama-3.2-3B-Instruct-Q4_K_M.gguf"

    static let shared = LlamaAIService()

    private var model:   OpaquePointer?
    private var context: OpaquePointer?
    private var vocab:   OpaquePointer?
    private var isLoaded = false

    private init() {}

    // MARK: - Public entry point (same signature — BudgetChatbotView needs no changes)

    static func ask(systemPrompt: String, userPrompt: String) async throws -> String {
        try await shared.generate(system: systemPrompt, user: userPrompt)
    }

    // MARK: - Load model (called once, stays in memory)

    func loadModelIfNeeded() throws {
        guard !isLoaded else { return }

        guard let modelPath = Bundle.main.path(forResource: kModelFilename, ofType: nil) else {
            throw LlamaError.modelNotFound(kModelFilename)
        }

        // Init backend once
        llama_backend_init()

        // Model params — offload all layers to Metal GPU
        var modelParams         = llama_model_default_params()
        modelParams.n_gpu_layers = 99

        // Load model using current API
        guard let loadedModel = llama_model_load_from_file(modelPath, modelParams) else {
            throw LlamaError.loadFailed
        }

        // Context params
        var ctxParams       = llama_context_default_params()
        ctxParams.n_ctx     = 2048
        ctxParams.n_batch   = 512
        ctxParams.n_threads = Int32(max(1, ProcessInfo.processInfo.activeProcessorCount - 1))

        // Create context using current API
        guard let ctx = llama_init_from_model(loadedModel, ctxParams) else {
            llama_model_free(loadedModel)
            throw LlamaError.contextFailed
        }

        model   = loadedModel
        context = ctx
        vocab   = llama_model_get_vocab(loadedModel)
        isLoaded = true
        print("✅ llama.cpp model loaded: \(kModelFilename)")
    }

    private func resetContext() throws {
        guard let model else { throw LlamaError.notLoaded }

        // free old context
        if let context {
            llama_free(context)
        }

        // recreate fresh context
        var ctxParams = llama_context_default_params()
        ctxParams.n_ctx = 2048

        guard let newContext = llama_new_context_with_model(model, ctxParams) else {
            throw LlamaError.loadFailed
        }
        context = newContext
        if context == nil {
            throw LlamaError.loadFailed
        }
    }
    
    //Formatting : Save16000 to Save 16,000
    func cleanPesoFormatting(_ text: String) -> String {
        var result = text
        
        // Fix missing space before numbers
        result = result.replacingOccurrences(
            of: #"([a-zA-Z])(\d)"#,
            with: "$1 $2",
            options: .regularExpression
        )
        
        // Fix ₱ formatting (ensure space after symbol)
        result = result.replacingOccurrences(
            of: #"₱(\d)"#,
            with: "₱ $1",
            options: .regularExpression
        )
        
        return result
    }
    // MARK: - Generate response

    func generate(system: String, user: String) throws -> String {
        try loadModelIfNeeded()
        try resetContext()
        guard let context, let vocab else {
            throw LlamaError.notLoaded
        }
        
        // Format as Llama 3 instruct template
        let prompt = """
        <|begin_of_text|><|start_header_id|>system<|end_header_id|>
        \(system)<|eot_id|><|start_header_id|>user<|end_header_id|>
        \(user)<|eot_id|><|start_header_id|>assistant<|end_header_id|>

        """

        // ── Tokenize ────────────────────────────────────────────────────────────
        let utf8Len   = Int32(prompt.utf8.count)
        let nEstimate = -llama_tokenize(vocab, prompt, utf8Len, nil, 0, true, true)
        var tokens    = [llama_token](repeating: 0, count: Int(nEstimate) + 4)
        let nTokens   = llama_tokenize(vocab, prompt, utf8Len, &tokens,
                                        Int32(tokens.count), true, true)
        guard nTokens > 0 else { throw LlamaError.tokenizeFailed }
        tokens = Array(tokens.prefix(Int(nTokens)))

        // ── Feed prompt tokens ──────────────────────────────────────────────────


        var batch = llama_batch_init(64, 0, 1)
        defer { llama_batch_free(batch) }

        for (i, token) in tokens.enumerated() {
            let isLast = (i == tokens.count - 1)
            batch.token[Int(batch.n_tokens)]    = token
            batch.pos[Int(batch.n_tokens)]      = Int32(i)
            batch.n_seq_id[Int(batch.n_tokens)] = 1
            batch.seq_id[Int(batch.n_tokens)]?[0] = 0
            batch.logits[Int(batch.n_tokens)]   = isLast ? 1 : 0
            batch.n_tokens += 1

            // Flush batch when full
            if batch.n_tokens == 64 && !isLast {
                guard llama_decode(context, batch) == 0 else { throw LlamaError.decodeFailed }
                batch.n_tokens = 0
            }
        }
        if batch.n_tokens > 0 {
            guard llama_decode(context, batch) == 0 else { throw LlamaError.decodeFailed }
        }

        // ── Sampler ─────────────────────────────────────────────────────────────
        var sparams   = llama_sampler_chain_default_params()
        sparams.no_perf = false
        let sampler   = llama_sampler_chain_init(sparams)
        defer { llama_sampler_free(sampler) }
        llama_sampler_chain_add(sampler, llama_sampler_init_temp(0.7))
        llama_sampler_chain_add(sampler, llama_sampler_init_top_p(0.9, 1))
        llama_sampler_chain_add(sampler,
            llama_sampler_init_dist(UInt32.random(in: 0...UInt32.max)))

        // ── Generate tokens ─────────────────────────────────────────────────────
        var output  = ""
        var nCur    = Int32(tokens.count)
        let maxNew  = Int32(300)

        for _ in 0 ..< maxNew {
            let newToken = llama_sampler_sample(sampler, context, -1)
            if llama_vocab_is_eog(vocab, newToken) { break }

            // Decode token → string
            var buf  = [CChar](repeating: 0, count: 64)
            let nBuf = llama_token_to_piece(vocab, newToken, &buf, Int32(buf.count), 0, true)
            if nBuf > 0 {
                let bytes = buf.prefix(Int(nBuf)).map { UInt8(bitPattern: $0) }
                output += String(bytes: bytes, encoding: .utf8) ?? ""
            }

            // Feed new token back
            llama_sampler_accept(sampler, newToken)

            var nb = llama_batch_init(1, 0, 1)
            nb.token[0]    = newToken
            nb.pos[0]      = nCur
            nb.n_seq_id[0] = 1
            nb.seq_id[0]?[0] = 0
            nb.logits[0]   = 1
            nb.n_tokens    = 1
            nCur += 1

            if llama_decode(context, nb) != 0 {
                llama_batch_free(nb)
                break
            }
            llama_batch_free(nb)
        }

        return cleanPesoFormatting(
            output.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    // MARK: - Errors

    enum LlamaError: LocalizedError {
        case modelNotFound(String)
        case loadFailed
        case contextFailed
        case notLoaded
        case tokenizeFailed
        case decodeFailed

        var errorDescription: String? {
            switch self {
            case .modelNotFound(let n): return "Model '\(n)' not found in app bundle. Drag it into Xcode."
            case .loadFailed:           return "Failed to load model. Check Increased Memory Limit entitlement."
            case .contextFailed:        return "Failed to create llama context."
            case .notLoaded:            return "Model not loaded."
            case .tokenizeFailed:       return "Tokenization failed."
            case .decodeFailed:         return "Decode step failed."
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════
// MARK: - Budget Context Builder  ← UNTOUCHED — identical to Groq version
// ═══════════════════════════════════════════════════════════════════════

struct BudgetContext {

    let rows: [BudgetRow]
    let remaining15: Double
    let remaining30: Double
    let firstCutoffDay: Int
    let secondCutoffDay: Int
    let userMessage: String

    var salary: Double         { sumAny(of: ["net salary","salary"]) }
    var savings: Double        { sum(keyword: "savings") }
    var emergencyFund: Double  { sum(keyword: "emergency fund") }

    var totalExpenses: Double {
        rows.filter {
            let n = $0.name.lowercased()
            return !(n.contains("salary") || n.contains("net salary") || n.contains("savings") || n.contains("emergency fund") || n.contains("emergency"))
        }.reduce(0) { $0 + amt($1.firstCutoff) + amt($1.secondCutoff) }
    }

    var fixedExpenses: Double {
        let kw = ["rent","mortgage","housing","utilities","internet","phone",
                  "insurance","tuition","loan","debt","subscription","autoloan",
                  "car","hmo","health","water","electric","power"]
        return rows.filter { r in kw.contains { r.name.lowercased().contains($0) } }
                   .reduce(0) { $0 + amt($1.firstCutoff) + amt($1.secondCutoff) }
    }

    var variableExpenses: Double { max(0, totalExpenses - fixedExpenses) }

    var remainingBalance: Double {
        let day = Calendar.current.component(.day, from: Date())
        return day <= firstCutoffDay ? remaining30 : remaining15
    }

    var daysLeft: Int {
        let cal   = Calendar.current
        let today = Date()
        func makeDate(_ d: Int, _ m: Int, _ y: Int) -> Date? {
            var c = DateComponents(); c.year=y; c.month=m; c.day=min(d,28)
            return cal.date(from: c)
        }
        let comps = cal.dateComponents([.year,.month], from: today)
        guard let y = comps.year, let m = comps.month else { return 0 }
        let nm  = cal.date(byAdding: .month, value: 1, to: today) ?? today
        let nmc = cal.dateComponents([.year,.month], from: nm)
        let candidates = [makeDate(firstCutoffDay,m,y), makeDate(secondCutoffDay,m,y),
                          makeDate(firstCutoffDay, nmc.month ?? m, nmc.year ?? y),
                          makeDate(secondCutoffDay, nmc.month ?? m, nmc.year ?? y)]
            .compactMap { $0 }.filter { $0 >= today }
        guard let nearest = candidates.sorted().first else { return 0 }
        return max(0, cal.dateComponents([.day],
            from: cal.startOfDay(for: today),
            to:   cal.startOfDay(for: nearest)).day ?? 0)
    }

    var dailyBudget: Double { remainingBalance / max(1, Double(daysLeft)) }

    var intent: String {
        let m = userMessage.lowercased()
        if m.contains("save") || m.contains("saving") || m.contains("boost") { return "save" }
        if m.contains("spend") || m.contains("buy")   || m.contains("can i") { return "spend" }
        if m.contains("invest")                                               { return "invest" }
        if m.contains("emergency") || m.contains("fund")                     { return "emergency" }
        if m.contains("cut") || m.contains("remove")  || m.contains("reduce"){ return "cut" }
        return "general"
    }

    var requestedAmount: Double {
        let pattern = #"[\d,]+"#
        if let r = userMessage.range(of: pattern, options: .regularExpression) {
            return Double(userMessage[r].replacingOccurrences(of: ",", with: "")) ?? 0
        }
        return 0
    }

    var canSpend: String? {
        guard requestedAmount > 0 else { return nil }
        return (remainingBalance - requestedAmount) >= (dailyBudget * Double(daysLeft) * 0.5) ? "YES" : "NO"
    }

    var savingsCapacity: String {
        if remainingBalance <= 0   { return "none" }
        if remainingBalance < 1000 { return "minimal" }
        if remainingBalance > 3000 { return "20-40%" }
        return "limited"
    }

    var emergencyMonths: Double   { emergencyFund / max(1, totalExpenses) }
    var canInvest: Bool           { emergencyMonths >= 3 }
    var emergencyPriority: String { emergencyMonths < 1 ? "HIGH" : emergencyMonths < 3 ? "MEDIUM" : "OK" }

    var isIncomeIntent: Bool {
        let m = userMessage.lowercased()
        return m.contains("income") || m.contains("kita") ||
               m.contains("extra income") || m.contains("sideline") || m.contains("freelance")
    }

    var budgetTableSummary: String {
        rows.compactMap { row -> String? in
            let f = amt(row.firstCutoff), s = amt(row.secondCutoff)
            guard f + s > 0 else { return nil }
            return "• \(row.name): ₱\(Int(f+s)) \(row.isEssential ? "[ESSENTIAL]" : "[OPTIONAL]")"
        }.joined(separator: "\n")
    }

    private func amt(_ s: String) -> Double { Double(s.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0 }
    private func sum(keyword: String) -> Double {
        rows.filter { $0.name.lowercased().contains(keyword) }
            .reduce(0) { $0 + amt($1.firstCutoff) + amt($1.secondCutoff) }
    }
    private func sumAny(of keywords: [String]) -> Double {
        rows.filter { row in
            let n = row.name.lowercased()
            return keywords.contains(where: { n.contains($0) })
        }.reduce(0) { $0 + amt($1.firstCutoff) + amt($1.secondCutoff) }
    }

    var systemPrompt: String { """
        You are Kinsenas AI, a smart Filipino budget assistant for 15-day salary cycles (kinsenas).
        NEVER return empty. ALWAYS give a direct, actionable response in 3–5 sentences max.
        Use ₱ for peso amounts. Be practical, not theoretical. No disclaimers.
        CRITICAL RULES:
        - NEVER suggest cutting loans, mortgage, rent, insurance, or essential bills
        - Items marked [ESSENTIAL] must NEVER be suggested for removal
        - ONLY suggest cutting items marked [OPTIONAL]
        RULES BY INTENT:
        - spend     → APPROVE or REJECT. Show math: remaining ÷ days left = daily budget.
        - save      → Give exact ₱ amount to save. Suggest 2 specific cuts from the user's actual expense list.
        - cut       → Name SPECIFIC [OPTIONAL] items. Show how much they'd save.
        - invest    → Only if emergency fund covers 3+ months. Otherwise redirect.
        - emergency → Show current months vs 3-month target.
        - income    → Suggest practical PH income ideas. Do NOT reference budget table.
        - general   → Practical advice using their actual numbers.
        TONE: Simple English, Filipino-friendly, like a kuya/ate who knows finance.
        IMPORTANT: Always refer to the user's actual budget items by name.
        """ }

    var userPrompt: String {
        if isIncomeIntent {
            return "User question: \(userMessage)\nIntent: income\nGive practical ways to earn extra income in the Philippines. DO NOT reference the budget table. Keep it short and actionable."
        }
        var lines = [
            "User question: \(userMessage)", "Intent: \(intent)", "",
            "=== BUDGET TABLE ===", budgetTableSummary, "",
            "=== FINANCIALS ===",
            "Net Salary: ₱\(Int(salary))",
            "Remaining balance: ₱\(Int(remainingBalance))",
            "Days until next cutoff: \(daysLeft)",
            "Daily budget: ₱\(Int(dailyBudget))",
            "Total expenses: ₱\(Int(totalExpenses))",
            "Fixed: ₱\(Int(fixedExpenses))  Variable: ₱\(Int(variableExpenses))",
            "Savings: ₱\(Int(savings))",
            "Emergency fund: ₱\(Int(emergencyFund)) (\(String(format:"%.1f", emergencyMonths)) months)",
            "Emergency priority: \(emergencyPriority)",
            "Can invest: \(canInvest)  Savings capacity: \(savingsCapacity)",
        ]
        if requestedAmount > 0 { lines.append("Requested spend: ₱\(Int(requestedAmount))") }
        if let cs = canSpend   { lines.append("Pre-computed spend decision: \(cs)") }
        lines += ["", "Give a clear, direct answer in 3-4 sentences using exact ₱ amounts and the user's actual expense item names."]
        return lines.joined(separator: "\n")
    }
}
