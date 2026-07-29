let tanpuraNotes: [String: Double] = [
    // --- Lower Octave (Kharaj) ---
    "Kharaj": 0.0,  // Low Sa
    "Re Komal": 100.0,
    "Re": 200.0,
    "Ga Komal": 300.0,
    "Ga Shuddha": 400.0,
    "Ma": 500.0,
    "Ma Teevra": 600.0,
    "Pa": 700.0,
    "Dha Komal": 800.0,
    "Dha": 900.0,
    "Ni Komal": 1000.0,
    "Ni": 1100.0,

    // --- Higher Octave ---
    "Sa": 1200.0,  // Middle Sa
    "Re Higher Komal": 1300.0,
    "Re Higher": 1400.0,
    "Ga Higher Komal": 1500.0,
    "Ga Higher": 1600.0,
    "Ma Higher": 1700.0,
]

enum TanpuraSeqElem {
    case Rest
    case Sa
    case Kharaj
    case Note(Double)

    // A helper property to get the label for your UI or backend
    var pitch: Double {
        switch self {
        case .Rest:
            return -1
        case .Sa:
            return tanpuraNotes["Sa"]!
        case .Kharaj:
            return tanpuraNotes["Kharaj"]!
        case .Note(let pitch):
            return pitch
        }
    }
}
