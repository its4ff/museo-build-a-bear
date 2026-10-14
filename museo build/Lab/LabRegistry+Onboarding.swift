#if DEBUG
import SwiftUI
import MuseoKit

/// First run: the onboarding steps and the cheat card. Each screen stages the model in one
/// state with no ring and no timers (`drivesItself: false`).
extension LabRegistry {
    static var onboarding: [LabScreen] {
        [
            LabScreen("onboarding.hello", title: "onboarding · hello", note: "the first screen, no ring yet") {
                LabOnboarding(Onboarding(ring: .notSetUp, actions: .preview, drivesItself: false))
            },
            LabScreen("onboarding.setup", title: "onboarding · set up", note: "the accessory sheet is up: choosing your ring") {
                LabOnboarding(Onboarding(
                    ring: LabOnboardingFixtures.choosing, actions: .preview, step: .setUp, drivesItself: false
                ))
            },
            LabScreen("onboarding.setup.linked", title: "onboarding · linked", note: "the beat before hold") {
                LabOnboarding(Onboarding(ring: .linked, actions: .preview, step: .setUp, drivesItself: false))
            },
            LabScreen("onboarding.stream", title: "onboarding · hold", note: "waiting for a hold") {
                LabOnboarding(Onboarding(ring: .linked, actions: .preview, step: .stream, drivesItself: false))
            },
            LabScreen("onboarding.stream.listening", title: "onboarding · listening", note: "holding the ring, the streaming card counting") {
                LabOnboarding(Onboarding(
                    ring: .live, actions: .preview, step: .stream,
                    stream: .listening(since: Date(timeIntervalSinceNow: -4)), drivesItself: false
                ))
                .environment(\.museLiveWords, LabFixtures.liveWords)
            },
            LabScreen(
                "onboarding.stream.landed",
                title: "onboarding · streamed in",
                note: "the muse landed, its words typing in",
                settle: .seconds(5)
            ) {
                LabOnboarding(Onboarding(
                    ring: .linked, actions: .preview, step: .stream,
                    stream: .landed(LabOnboardingFixtures.streamed), drivesItself: false
                ))
            },
            LabScreen("onboarding.memory", title: "onboarding · double click", note: "waiting for a double click") {
                LabOnboarding(Onboarding(ring: .linked, actions: .preview, step: .memory, drivesItself: false))
            },
            LabScreen("onboarding.memory.recording", title: "onboarding · recording", note: "recording on the ring, amber") {
                LabOnboarding(Onboarding(
                    ring: LabOnboardingFixtures.recording, actions: .preview, step: .memory,
                    memory: .recording(since: Date(timeIntervalSinceNow: -3)), drivesItself: false
                ))
            },
            LabScreen(
                "onboarding.memory.landed",
                title: "onboarding · that's memory",
                note: "it came in from the ring",
                settle: .seconds(5)
            ) {
                LabOnboarding(Onboarding(
                    ring: .linked, actions: .preview, step: .memory,
                    memory: .landed(LabOnboardingFixtures.memory), drivesItself: false
                ))
            },
            LabScreen("onboarding.card", title: "onboarding · the card", note: "the last step: the cheat card and start") {
                LabOnboarding(Onboarding(ring: .linked, actions: .preview, step: .card, drivesItself: false))
            },
            LabScreen("cheatcard", title: "cheat card", note: "the page as the home's question mark opens it") {
                RingCheatPage()
            },
            LabScreen("cheatcard.2", title: "cheat card · 2", note: "the end: charging and care") {
                RingCheatPage()
                    .labScrolled(LabScroll.end)
            },
            LabScreen("cheatcard.docs", title: "cheat card · docs", note: "the whole card on one screen, for docs/cheat-sheet.png") {
                // Laid out wider, then scaled to the screen's width, so the whole card fits
                // one screenshot. An overlay, so the taller layout hangs from the top.
                MuseBackground()
                    .overlay(alignment: .top) {
                        VStack(alignment: .leading, spacing: MuseSpacing.lg) {
                            MuseHeader(title: "how \(AppConfig.appName) works.", subtitle: "the ring in one card.", titleSize: 28)
                            RingCheatCard()
                        }
                        .padding(.horizontal, MuseSpacing.page)
                        .frame(width: 600)
                        .scaleEffect(0.655, anchor: .top)
                        .padding(.top, MuseSpacing.section * 2)
                    }
            },
            LabScreen("art", title: "the drawings", note: "the ring, its band lit both ways, the case") {
                ScrollView {
                    VStack(spacing: MuseSpacing.section) {
                        MuseRingArt(width: 260)
                        HStack(alignment: .bottom, spacing: MuseSpacing.section) {
                            MuseRingBand(light: .white, lit: true, height: 200)
                            MuseRingBand(light: .amber, lit: true, height: 200)
                        }
                        HStack(alignment: .bottom, spacing: MuseSpacing.section) {
                            MuseCaseArt(pose: .open, width: 110)
                            MuseCaseArt(pose: .closed, width: 110)
                        }
                        MuseHandArt(width: 260)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, MuseSpacing.section)
                }
                .scrollIndicators(.hidden)
                .background { MuseBackground() }
            },
        ]
    }
}

/// Keeps one staged model for the life of the screen.
private struct LabOnboarding: View {
    @State private var model: Onboarding

    init(_ model: @autoclosure () -> Onboarding) {
        _model = State(initialValue: model())
    }

    var body: some View {
        OnboardingView(model: model)
    }
}

@MainActor
private enum LabOnboardingFixtures {
    static var choosing: RingStatus {
        var status = RingStatus.notSetUp
        status.isSettingUp = true
        return status
    }

    static var recording: RingStatus {
        var status = RingStatus.linked
        status.isRecordingOnRing = true
        return status
    }

    /// Held and said a moment ago, its words just in.
    static var streamed: Muse {
        Muse(
            createdAt: LabFixtures.now.addingTimeInterval(-6),
            duration: 4,
            origin: .stream,
            transcript: "the light on the canal at six is the green we want for the box.",
            transcriptionState: .complete,
            language: "en",
            arrivedAt: .now
        )
    }

    /// Double clicked, said, double clicked, brought in from the ring.
    static var memory: Muse {
        Muse(
            createdAt: LabFixtures.now.addingTimeInterval(-20),
            duration: 7,
            origin: .offline,
            transcript: "ask the bakery on fifth if they still do the rye on saturdays, and what time it's out.",
            transcriptionState: .complete,
            title: "rye on saturdays",
            language: "en",
            arrivedAt: .now
        )
    }
}
#endif
