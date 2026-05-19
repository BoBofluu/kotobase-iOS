import Foundation

/// Gemini TTS 性別
enum GeminiVoiceGender: String {
    case female = "FEMALE"
    case male = "MALE"

    var label: String {
        switch self {
        case .female: return "女"
        case .male: return "男"
        }
    }
}

/// Gemini TTS 預設語音
struct GeminiVoice: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let gender: GeminiVoiceGender
}

/// Gemini TTS 風格指令預設
struct PromptPreset: Identifiable, Hashable {
    let id: String
    let label: String
    let value: String
}

/// 對應 Web 版 GEMINI_VOICES（20 個）
let geminiVoices: [GeminiVoice] = [
    GeminiVoice(name: "Achernar",      gender: .female),
    GeminiVoice(name: "Algenib",       gender: .male),
    GeminiVoice(name: "Alnilam",       gender: .male),
    GeminiVoice(name: "Aoede",         gender: .female),
    GeminiVoice(name: "Autonoe",       gender: .female),
    GeminiVoice(name: "Callirrhoe",    gender: .female),
    GeminiVoice(name: "Despina",       gender: .female),
    GeminiVoice(name: "Erinome",       gender: .female),
    GeminiVoice(name: "Gacrux",        gender: .male),
    GeminiVoice(name: "Laomedeia",     gender: .female),
    GeminiVoice(name: "Puck",          gender: .male),
    GeminiVoice(name: "Rasalgethi",    gender: .male),
    GeminiVoice(name: "Sadachbia",     gender: .male),
    GeminiVoice(name: "Sadatoni",      gender: .male),
    GeminiVoice(name: "Schedar",       gender: .male),
    GeminiVoice(name: "Sulafat",       gender: .female),
    GeminiVoice(name: "Umbriel",       gender: .male),
    GeminiVoice(name: "Vindemiatrix",  gender: .female),
    GeminiVoice(name: "Zephyr",        gender: .male),
    GeminiVoice(name: "Zubenelgenubi", gender: .male)
]

/// 對應 Web 版 PROMPT_PRESETS（9 個）
let promptPresets: [PromptPreset] = [
    PromptPreset(
        id: "natural",
        label: "🎙️ 自然・穩定",
        value: "自然で安定した話し方で、呼吸音があり、少し抑揚をつけて読んでください。"
    ),
    PromptPreset(
        id: "teacher",
        label: "📖 教師朗讀",
        value: "教師が教科書を読むように、はっきりと正確な発音で読んでください。試験のリスニング練習に適したスタイルで。"
    ),
    PromptPreset(
        id: "anime-girl",
        label: "✨ 動漫女角・元氣",
        value: "アニメの元気な女の子キャラクターのように、明るく活発に、感情豊かに読んでください。"
    ),
    PromptPreset(
        id: "chuuni-boy",
        label: "⚔️ 中二男角",
        value: "中二病の男キャラクターのように、大げさで芝居がかった口調で、ドラマチックに読んでください。"
    ),
    PromptPreset(
        id: "host-idol",
        label: "💎 牛郎・偶像磁性",
        value: "ホストやアイドルのように、色気があり磁力のある声で、甘くささやくように読んでください。"
    ),
    PromptPreset(
        id: "news",
        label: "📺 NHKニュース",
        value: "NHKのニュースアナウンサーのように、落ち着いた正確な標準語で、丁寧に読んでください。"
    ),
    PromptPreset(
        id: "grandma",
        label: "👵 優しいおばあちゃん",
        value: "おばあちゃんが孫に話しかけるように、温かくゆっくりと優しい口調で読んでください。"
    ),
    PromptPreset(
        id: "samurai",
        label: "⚔️ 武士・時代劇",
        value: "時代劇の武士のように、威厳があり力強い口調で読んでください。"
    ),
    PromptPreset(
        id: "whisper",
        label: "🌙 ASMR囁き",
        value: "ASMRのように、そっと囁くような小さな声で、リラックスできるように読んでください。"
    )
]

/// 預設 Gemini 風格指令
let defaultGeminiPrompt = "Read aloud in a warm, welcoming tone."

/// Wavenet 標準女聲
let standardFemaleVoice = "ja-JP-Wavenet-A"

/// Wavenet 標準男聲（對應 Web 版）
let standardMaleVoice = "ja-JP-Wavenet-C"
