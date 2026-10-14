import SwiftUI

/// A 0.75pt hairline rule, for rows that are just a list.
struct MuseHairline: View {
    var body: some View {
        Rectangle()
            .fill(MuseColor.hairline)
            .frame(height: 0.75)
            .accessibilityHidden(true)
    }
}
