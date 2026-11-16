import MuseoKit
import SwiftUI

/// The panel's row for recordings on the ring that aren't on this mac yet (s1 on the design
/// canvas). Waiting: how many, roughly how long, and "bring in". Bringing in: which one of
/// how many, a bar, and "stop" (the one coming in finishes first). Done: says so once, for a
/// few seconds, then goes away. Hidden when there's nothing to bring in.
struct RingSyncRow: View {
    let ring: RingStatus
    let actions: RingActions
    let openLibrary: () -> Void

    /// How many the sync in flight set out to bring in, kept for the done line.
    @State private var total = 0
    @State private var stopping = false
    @State private var done: String?

    /// A mac brings recordings over at about 8 KB/s until one has been timed.
    private static let assumedRate: Double = 8_000

    var body: some View {
        Group {
            if ring.isSyncing {
                bringingIn
            } else if let done {
                finished(done)
            } else if waiting > 0, ring.isLinked, !ring.isLive, !ring.isRecordingOnRing {
                ready
            }
        }
        .onChange(of: ring.isSyncing) { was, now in
            if now {
                done = nil
            } else if was {
                let left = waiting
                done = left == 0 ? (total == 1 ? "it's on this mac" : "all \(total) are on this mac") : "\(total) brought in · \(left) still on the ring"
                stopping = false
                Task {
                    try? await Task.sleep(for: .seconds(5))
                    done = nil
                }
            }
        }
        .onChange(of: ring.syncTotal, initial: true) { _, count in
            if count > 0 { total = count }
        }
    }

    /// Everything on the ring not on this mac: new recordings and the ones from before.
    private var waiting: Int { ring.waiting + ring.olderWaiting }

    // MARK: - States

    private var ready: some View {
        HStack(spacing: MuseSpacing.xs) {
            Circle().fill(MuseColor.ochre).frame(width: 6, height: 6)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(waiting == 1 ? "1 on the ring" : "\(waiting) on the ring")
                    .font(MuseType.metaMedium)
                    .foregroundStyle(MuseColor.ink)
                Text("not on this mac · \(Self.about(seconds: Double(ring.waitingBytes) / rate))")
                    .font(MuseType.caption)
                    .foregroundStyle(MuseColor.ink55)
            }
            Spacer(minLength: MuseSpacing.xs)
            Button {
                total = waiting
                actions.bringInEverything()
            } label: {
                Text("bring in")
                    .font(MuseType.captionMedium)
                    .foregroundStyle(MuseColor.ground)
                    .padding(.horizontal, 11)
                    .frame(height: 26)
                    .background(MuseColor.primaryGradient, in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(MusePressStyle())
        }
        .padding(.leading, MuseSpacing.sm)
        .padding(.trailing, MuseSpacing.xs)
        .padding(.vertical, MuseSpacing.xs)
        .museInsetSurface()
    }

    private var bringingIn: some View {
        let count = max(ring.syncTotal, total, 1)
        let left = max(ring.waiting, 1)
        let current = min(max(count - left + 1, 1), count)
        let share = (Double(current - 1) + (ring.syncProgress ?? 0)) / Double(count)
        return VStack(alignment: .leading, spacing: 7) {
            Text(stopping ? "finishing this one…" : (count == 1 ? "bringing it in…" : "bringing in \(current) of \(count)…"))
                .font(MuseType.metaMedium)
                .foregroundStyle(MuseColor.ink)
                .monospacedDigit()
            ProgressBar(share: share)
            HStack {
                Text("\(Self.about(seconds: Double(ring.syncBytesLeft) / rate)) left")
                    .font(MuseType.caption)
                    .foregroundStyle(MuseColor.ink55)
                Spacer(minLength: MuseSpacing.xs)
                if !stopping, count - current > 0 {
                    Button {
                        stopping = true
                        actions.stopSync()
                    } label: {
                        Text("stop")
                            .font(MuseType.captionMedium)
                            .foregroundStyle(MuseColor.ink70)
                            .frame(minWidth: 44, minHeight: 20, alignment: .trailing)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("the one coming in now finishes, the rest stay on the ring")
                }
            }
        }
        .padding(.horizontal, MuseSpacing.sm)
        .padding(.vertical, MuseSpacing.xs)
        .museInsetSurface()
    }

    private func finished(_ line: String) -> some View {
        HStack(spacing: MuseSpacing.xs) {
            Image(systemName: "checkmark")
                .font(MuseFont.symbol(11))
                .foregroundStyle(MuseColor.moss)
                .accessibilityHidden(true)
            Text(line)
                .font(MuseType.meta)
                .foregroundStyle(MuseColor.ink)
            Spacer(minLength: MuseSpacing.xs)
            Button("open museo", action: openLibrary)
                .buttonStyle(.plain)
                .font(MuseType.captionMedium)
                .foregroundStyle(MuseColor.moss600)
        }
        .padding(.horizontal, MuseSpacing.sm)
        .frame(minHeight: 36)
        .museInsetSurface()
    }

    // MARK: - Time

    private var rate: Double { max(ring.transferRate ?? Self.assumedRate, 1_000) }

    /// "under a minute", "about 4 min", "about 2 h".
    static func about(seconds: Double) -> String {
        switch seconds {
        case ..<60: "under a minute"
        case ..<(90 * 60): "about \(Int((seconds / 60).rounded())) min"
        default: "about \(Int((seconds / 3600).rounded())) h"
        }
    }
}

/// A thin amber bar: how far the sync has come.
private struct ProgressBar: View {
    let share: Double

    var body: some View {
        Capsule()
            .fill(MuseColor.ink.opacity(0.08))
            .frame(height: 4)
            .overlay {
                Rectangle()
                    .fill(LinearGradient(colors: [MuseColor.ochre, MuseColor.ringAmber], startPoint: .leading, endPoint: .trailing))
                    .scaleEffect(x: min(max(share, 0.03), 1), anchor: .leading)
            }
            .clipShape(Capsule())
            .museAnimation(MuseMotion.gentle, value: share)
            .accessibilityElement()
            .accessibilityLabel("brought in")
            .accessibilityValue("\(Int(share * 100)) percent")
    }
}
