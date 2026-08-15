import SwiftUI

// MARK: - Sankalp Practice Log Card View
struct SankalpCardView: View {
    @ObservedObject var audio: AppAudioOrchestrator
    @State private var isShowingLogDialog = false
    
    var body: some View {
        let isAntique = audio.isAntiqueThemeEnabled
        VStack(alignment: .leading, spacing: 14) {
            // Header Row
            HStack(spacing: 8) {
                Image(systemName: "clock.badge.checkmark.fill")
                    .foregroundColor(isAntique ? Color.orange : .accentColor)
                Text("Sankalp Practice Log")
                    .font(isAntique ? .custom("Snell Roundhand", size: 20).weight(.bold) : .headline)
                    .foregroundColor(isAntique ? Color.orange : .primary)
                Spacer()
            }
            
            // Stats Row
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SESSION")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                    Text(formatDuration(seconds: audio.sessionSeconds))
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(isAntique ? Color.yellow : .primary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("TODAY")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                    Text(formatDuration(seconds: audio.dailySeconds))
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(isAntique ? Color.yellow : .primary)
                }
            }
            .padding(.vertical, 2)
            
            // Log Button
            Button(action: {
                isShowingLogDialog = true
            }) {
                HStack {
                    Spacer()
                    Image(systemName: "square.and.pencil")
                    Text("Log Sankalp")
                        .fontWeight(.medium)
                    Spacer()
                }
                .padding(.vertical, 6)
            }
            .buttonStyle(SankalpButtonStyle(isProminent: !audio.hasLoggedToday, isAntique: isAntique))
        }
        .padding(16)
        .frame(width: 340)
        .nativeCard(isAntique: isAntique, cornerRadius: 16)
        .sheet(isPresented: $isShowingLogDialog) {
            SankalpLogDialog(audio: audio, isPresented: $isShowingLogDialog)
        }
    }
    
    private func formatDuration(seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return "\(mins)m \(secs)s"
    }
}
