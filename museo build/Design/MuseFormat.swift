import Foundation

// Times, durations and copy cleanup in the house voice: lowercase, middle dots, no dashes.
// `museCalm` is for model output and the person's words (names keep their case);
// `museQuiet` is for system and library errors (all lowercase).

nonisolated extension Date {
    /// "9:41a", "12:05p".
    var museClock: String {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: self)
        let minute = calendar.component(.minute, from: self)
        let h12 = hour % 12 == 0 ? 12 : hour % 12
        return String(format: "%d:%02d%@", h12, minute, hour < 12 ? "a" : "p")
    }

    /// "now", "2m ago", "3h ago", "yesterday", "oct 8", "oct 8 2025".
    func museRelative(now: Date = .now) -> String {
        let seconds = now.timeIntervalSince(self)
        if seconds < 45 { return "now" }
        if seconds < 3600 { return "\(max(1, Int(seconds / 60)))m ago" }
        let calendar = Calendar.current
        if calendar.isDate(self, inSameDayAs: now) { return "\(Int(seconds / 3600))h ago" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(self, inSameDayAs: yesterday) { return "yesterday" }
        return museShortDate(now: now)
    }

    var museRelative: String { museRelative() }

    /// "oct 8", or "oct 8 2025" in another year.
    func museShortDate(now: Date = .now) -> String {
        let sameYear = Calendar.current.component(.year, from: self) == Calendar.current.component(.year, from: now)
        let style = sameYear
            ? Date.FormatStyle().month(.abbreviated).day()
            : Date.FormatStyle().month(.abbreviated).day().year()
        return formatted(style).replacingOccurrences(of: ",", with: "").lowercased()
    }

    /// Day headers: "today", "yesterday", "wednesday october 8".
    func museDayTitle(now: Date = .now) -> String {
        let calendar = Calendar.current
        if calendar.isDate(self, inSameDayAs: now) { return "today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(self, inSameDayAs: yesterday) { return "yesterday" }
        var style = Date.FormatStyle().weekday(.wide).month(.wide).day()
        if calendar.component(.year, from: self) != calendar.component(.year, from: now) {
            style = style.year()
        }
        return formatted(style).replacingOccurrences(of: ",", with: "").lowercased()
    }

    var museDayTitle: String { museDayTitle() }

    /// The muse page header: "wednesday oct 8".
    var musePageDate: String {
        formatted(Date.FormatStyle().weekday(.wide).month(.abbreviated).day())
            .replacingOccurrences(of: ",", with: "")
            .lowercased()
    }
}

nonisolated extension TimeInterval {
    /// "0:07", "4:12", "1:02:19".
    var museDuration: String {
        let total = Int(self.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 { return String(format: "%d:%02d:%02d", hours, minutes, seconds) }
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// "48m", "1h 12m", "about 3 h" style for storage left.
    var museMinutesShort: String {
        let minutes = Int(self / 60)
        if minutes < 60 { return "\(minutes)m" }
        let h = minutes / 60, m = minutes % 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }
}

nonisolated extension String {
    /// Model output and the person's own words in the house voice: no em or en dashes, no
    /// exclamation marks, tidy spaces. Case stays, so the names they said ("Dr. Patel",
    /// "Lisbon") stay too. Hyphens inside words ("wi-fi") stay, and an en dash between
    /// two things with no spaces ("2–3 weeks") becomes a hyphen ("2-3 weeks").
    var museCalm: String {
        replacingOccurrences(of: " — ", with: ", ")
            .replacingOccurrences(of: "—", with: ", ")
            .replacingOccurrences(of: " – ", with: ", ")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "!", with: "")
            .replacingOccurrences(of: ", ,", with: ",")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// System and library text (errors, statuses) in the house voice: `museCalm`, then all
    /// lowercase. Not for model answers or their words; those use `museCalm`.
    var museQuiet: String {
        museCalm.lowercased()
    }

    /// Lock-screen and card text from a model or the person: markdown stripped, calm (case
    /// kept), cut at a sentence or word under `max`. Lowercase system text yourself first
    /// with `museQuiet`.
    func musePlain(max: Int) -> String {
        var text = self
        for mark in ["**", "__", "`", "#", "> "] { text = text.replacingOccurrences(of: mark, with: "") }
        text = text.replacingOccurrences(of: "\n", with: " ").museCalm
        guard text.count > max else { return text }
        let cut = String(text.prefix(max))
        if let end = cut.lastIndex(where: { ".?".contains($0) }),
           cut.distance(from: cut.startIndex, to: end) > max / 2 {
            return String(cut[...end])
        }
        if let space = cut.lastIndex(of: " "), cut.distance(from: cut.startIndex, to: space) > (max * 6) / 10 {
            return String(cut[..<space])
        }
        return cut
    }

    /// Their words wrapped in curly quotes, for cards.
    var museQuoted: String { "\u{201C}\(self)\u{201D}" }
}
