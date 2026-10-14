import SwiftUI

/// A tracked, lowercase section label in Satoshi 11 (`MuseType.eyebrow`).
struct MuseEyebrow: View {
    let text: String
    var color: Color = MuseColor.ink55

    init(_ text: String, color: Color = MuseColor.ink55) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(MuseType.eyebrow)
            .tracking(MuseType.eyebrowTracking)
            .foregroundStyle(color)
    }
}
