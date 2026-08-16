import SwiftUI

// MARK: - Sankalp Practice Log Card View
struct SankalpCardView: View {
    @ObservedObject var sankalp: SankalpPracticeManager
    var isAntique: Bool = false
    
    @State private var isShowingLogDialog = false
    @State private var isShowingResetSessionAlert = false
    @State private var isShowingResetDailyAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header Row
            HStack(spacing: 8) {
                Circle()
                    .fill(sankalp.isPlaying ? Color.green : Color.gray.opacity(0.4))
                    .frame(width: 8, height: 8)
                    .shadow(color: sankalp.isPlaying ? Color.green.opacity(0.8) : Color.clear, radius: 4)
                
                Image(systemName: "clock.badge.checkmark.fill")
                    .foregroundColor(isAntique ? Color.orange : .accentColor)
                Text("Sankalp Practice Log")
                    .font(isAntique ? .custom("Snell Roundhand", size: 20).weight(.bold) : .headline)
                    .foregroundColor(isAntique ? Color.orange : .primary)
                Spacer()
            }
            
            // Stats Row with Minute Precision and Reset Controls
            HStack(spacing: 32) {
                // Session Stat Box
                VStack(alignment: .leading, spacing: 4) {
                    Text("SESSION")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        Text(SankalpPracticeManager.formatMinutes(sankalp.sessionMinutes))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(isAntique ? Color.yellow : .primary)

                        Button(action: { isShowingResetSessionAlert = true }) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(isAntique ? Color.orange.opacity(0.8) : .secondary)
                                .padding(4)
                                .background(
                                    Circle()
                                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.6))
                                )
                        }
                        .buttonStyle(.plain)
                        .help("Reset Session Time")
                    }
                }

                // Today Stat Box
                VStack(alignment: .leading, spacing: 4) {
                    Text("TODAY")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        Text(SankalpPracticeManager.formatMinutes(sankalp.dailyMinutes))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(isAntique ? Color.yellow : .primary)

                        Button(action: { isShowingResetDailyAlert = true }) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(isAntique ? Color.orange.opacity(0.8) : .secondary)
                                .padding(4)
                                .background(
                                    Circle()
                                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.6))
                                )
                        }
                        .buttonStyle(.plain)
                        .help("Reset Today's Time")
                    }
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
            .buttonStyle(SankalpButtonStyle(isProminent: !sankalp.hasLoggedToday, isAntique: isAntique))
        }
        .padding(16)
        .frame(width: 340)
        .nativeCard(isAntique: isAntique, cornerRadius: 16)
        .sheet(isPresented: $isShowingLogDialog) {
            SankalpLogDialog(sankalp: sankalp, isAntique: isAntique, isPresented: $isShowingLogDialog)
        }
        .alert("Reset Session Time?", isPresented: $isShowingResetSessionAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                sankalp.resetSessionTime()
            }
        } message: {
            Text("Are you sure you want to reset your current session practice timer to 0m?")
        }
        .alert("Reset Today's Time?", isPresented: $isShowingResetDailyAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                sankalp.resetDailyTime()
            }
        } message: {
            Text("Are you sure you want to reset today's accumulated practice timer to 0m?")
        }
    }
}

#Preview {
    SankalpCardView(sankalp: SankalpPracticeManager())
}
