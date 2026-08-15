import SwiftUI

// MARK: - Sankalp Practice Log Submission Dialog
struct SankalpLogDialog: View {
    @ObservedObject var sankalp: SankalpPracticeManager
    var isAntique: Bool = false
    @Binding var isPresented: Bool
    
    @State private var minutes: Int = 1
    @State private var date: Date = Date()
    @State private var summary: String = ""
    @State private var sankalpWord: String = ""
    
    @State private var isSubmitting = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title
            Text("Submit Sankalp Practice Log")
                .font(isAntique ? .custom("Snell Roundhand", size: 22).weight(.bold) : .title2)
                .foregroundColor(isAntique ? Color.orange : .primary)
                .padding(.bottom, 2)
            
            // Student Info Summary
            VStack(alignment: .leading, spacing: 4) {
                Text("STUDENT INFO")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                if sankalp.studentID.isEmpty || sankalp.firstName.isEmpty || sankalp.lastName.isEmpty || sankalp.email.isEmpty {
                    Text("⚠️ Warning: Sankalp Form Info is incomplete. Please configure it in Settings first.")
                        .font(.caption)
                        .foregroundColor(.red)
                } else {
                    Text("\(sankalp.firstName) \(sankalp.lastName) (\(sankalp.studentID))")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Text("\(sankalp.email) — Batch: \(sankalp.batch)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isAntique ? Color.black.opacity(0.2) : Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            
            // Inputs List
            VStack(spacing: 12) {
                // Practice Date Row
                HStack {
                    Text("Practice Date")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    DatePicker("", selection: $date, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                }
                
                // Minutes Practiced Row
                HStack {
                    Text("Minutes Practiced")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    HStack(spacing: 6) {
                        TextField("", value: $minutes, formatter: NumberFormatter())
                            .frame(width: 60)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing)
                        Stepper("", value: $minutes, in: 1...1440)
                            .labelsHidden()
                    }
                }
                
                // Practice Summary
                VStack(alignment: .leading, spacing: 6) {
                    Text("Practice Summary (Optional)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    TextEditor(text: $summary)
                        .frame(height: 80)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isAntique ? Color.orange.opacity(0.4) : Color.gray.opacity(0.2), lineWidth: 1)
                        )
                }
                
                // Sankalp Word
                VStack(alignment: .leading, spacing: 6) {
                    Text("Sankalp Word (Optional)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    TextField("Enter Sankalp word", text: $sankalpWord)
                        .textFieldStyle(.roundedBorder)
                }
            }
            
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            // Buttons
            HStack(spacing: 12) {
                Spacer()
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                .disabled(isSubmitting)
                
                Button(action: submitLog) {
                    if isSubmitting {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 60, height: 16)
                    } else {
                        Text("Submit Log")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSubmitting || sankalp.studentID.isEmpty || sankalp.firstName.isEmpty || sankalp.lastName.isEmpty || sankalp.email.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 420)
        .onAppear {
            // Prefill with active session minutes (default 1 if 0)
            self.minutes = max(1, sankalp.sessionMinutes)
            self.summary = UserDefaults.standard.string(forKey: "SankalpLastPracticeSummary") ?? ""
            self.sankalpWord = UserDefaults.standard.string(forKey: "SankalpLastWord") ?? ""
        }
    }
    
    private func submitLog() {
        isSubmitting = true
        errorMessage = nil
        
        Task {
            do {
                try await sankalp.submitForm(
                    studentId: sankalp.studentID,
                    firstName: sankalp.firstName,
                    lastName: sankalp.lastName,
                    email: sankalp.email,
                    batch: sankalp.batch,
                    minutes: minutes,
                    summary: summary,
                    sankalpWord: sankalpWord,
                    date: date
                )
                
                // Save last used parameters for prefill
                UserDefaults.standard.set(summary, forKey: "SankalpLastPracticeSummary")
                UserDefaults.standard.set(sankalpWord, forKey: "SankalpLastWord")
                
                // Mark as logged today
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                let todayStr = formatter.string(from: Date())
                sankalp.lastLogDateString = todayStr
                UserDefaults.standard.set(todayStr, forKey: "SankalpLastLogDate")
                
                // Reset session seconds
                sankalp.resetSessionTime()
                
                isSubmitting = false
                isPresented = false
            } catch {
                errorMessage = "❌ Submission failed: \(error.localizedDescription)"
                isSubmitting = false
            }
        }
    }
}
