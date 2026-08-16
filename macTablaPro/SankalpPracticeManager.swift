import SwiftUI
import Combine

// MARK: - Sankalp Practice Manager Service
class SankalpPracticeManager: ObservableObject {
    static let shared = SankalpPracticeManager()
    
    @Published var sessionSeconds: TimeInterval = 0.0
    @Published var dailySeconds: TimeInterval = 0.0
    @Published var lastLogDateString: String = ""
    
    @Published var studentID: String = "" {
        didSet { UserDefaults.standard.set(studentID, forKey: "SankalpStudentID") }
    }
    @Published var firstName: String = "" {
        didSet { UserDefaults.standard.set(firstName, forKey: "SankalpFirstName") }
    }
    @Published var lastName: String = "" {
        didSet { UserDefaults.standard.set(lastName, forKey: "SankalpLastName") }
    }
    @Published var email: String = "" {
        didSet { UserDefaults.standard.set(email, forKey: "SankalpEmail") }
    }
    @Published var batch: String = "" {
        didSet { UserDefaults.standard.set(batch, forKey: "SankalpBatch") }
    }
    
    var sessionMinutes: Int {
        return max(0, Int(sessionSeconds / 60.0))
    }
    
    var dailyMinutes: Int {
        return max(0, Int(dailySeconds / 60.0))
    }
    
    var hasLoggedToday: Bool {
        return lastLogDateString == getTodayDateString()
    }
    
    private var practiceTimer: Timer?
    @Published var isPlaying: Bool = false
    
    init() {
        self.studentID = UserDefaults.standard.string(forKey: "SankalpStudentID") ?? ""
        self.firstName = UserDefaults.standard.string(forKey: "SankalpFirstName") ?? ""
        self.lastName = UserDefaults.standard.string(forKey: "SankalpLastName") ?? ""
        self.email = UserDefaults.standard.string(forKey: "SankalpEmail") ?? ""
        self.batch = UserDefaults.standard.string(forKey: "SankalpBatch") ?? "Test Batch"
        self.lastLogDateString = UserDefaults.standard.string(forKey: "SankalpLastLogDate") ?? ""
        self.dailySeconds = UserDefaults.standard.double(forKey: "SankalpDailySeconds")
        
        checkDailySecondsReset()
    }
    
    // MARK: - Playback Signal
    func onPlaybackStateChanged(isPlaying: Bool) {
        Task { @MainActor in
            self.isPlaying = isPlaying
            if isPlaying {
                self.startPracticeTimerIfNeeded()
            } else {
                self.stopPracticeTimer()
            }
        }
    }
    
    private func startPracticeTimerIfNeeded() {
        guard practiceTimer == nil else { return }
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.tickPracticeTime()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        practiceTimer = timer
    }
    
    private func stopPracticeTimer() {
        practiceTimer?.invalidate()
        practiceTimer = nil
    }
    
    @MainActor
    private func tickPracticeTime() {
        checkDailySecondsReset()
        if isPlaying {
            sessionSeconds += 1.0
            dailySeconds += 1.0
            UserDefaults.standard.set(dailySeconds, forKey: "SankalpDailySeconds")
        }
    }
    
    @MainActor
    private func checkDailySecondsReset() {
        let todayStr = getTodayDateString()
        let lastResetDate = UserDefaults.standard.string(forKey: "SankalpDailyResetDate") ?? ""
        if todayStr != lastResetDate {
            dailySeconds = 0.0
            UserDefaults.standard.set(0.0, forKey: "SankalpDailySeconds")
            UserDefaults.standard.set(todayStr, forKey: "SankalpDailyResetDate")
        }
    }
    
    func resetSessionTime() {
        sessionSeconds = 0.0
    }
    
    func resetDailyTime() {
        dailySeconds = 0.0
        sessionSeconds = 0.0
        UserDefaults.standard.set(0.0, forKey: "SankalpDailySeconds")
    }
    
    private func getTodayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    // MARK: - Human Readable Minutes Formatting (e.g. 45m, 1h 2m)
    static func formatMinutes(_ totalMinutes: Int) -> String {
        if totalMinutes < 60 {
            return "\(totalMinutes)m"
        } else {
            let hours = totalMinutes / 60
            let mins = totalMinutes % 60
            return "\(hours)h \(mins)m"
        }
    }
    
    // MARK: - Google Forms Native HTTP Submission
    func submitForm(
        studentId: String,
        firstName: String,
        lastName: String,
        email: String,
        batch: String,
        minutes: Int,
        summary: String,
        sankalpWord: String,
        date: Date
    ) async throws {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        
        let urlString = "https://docs.google.com/forms/u/0/d/e/1FAIpQLSdmGU8uxDgCLlpqIs2uoLcCn1mKd33WjO-SOeDL01mPxKpPkg/formResponse"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/151.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "entry.1742760532", value: studentId),
            URLQueryItem(name: "entry.1992748701", value: firstName),
            URLQueryItem(name: "entry.1182588695", value: lastName),
            URLQueryItem(name: "entry.1838437624", value: email),
            URLQueryItem(name: "entry.2040019182", value: batch),
            URLQueryItem(name: "entry.1586397793", value: String(minutes)),
            URLQueryItem(name: "entry.193868850", value: summary),
            URLQueryItem(name: "entry.1865891008", value: sankalpWord),
            URLQueryItem(name: "entry.737772668_year", value: String(year)),
            URLQueryItem(name: "entry.737772668_month", value: String(month)),
            URLQueryItem(name: "entry.737772668_day", value: String(day)),
            URLQueryItem(name: "pageHistory", value: "0"),
            URLQueryItem(name: "fvv", value: "1")
        ]
        
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
            
        guard httpResponse.statusCode == 200 else {
            throw URLError(.init(rawValue: httpResponse.statusCode))
        }
    }
}
