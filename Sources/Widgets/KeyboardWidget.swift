import SwiftUI

public struct KeyboardView: View {
    let layout: String
    @State private var wiggle = false

    public init(layout: String) { self.layout = layout }

    public var body: some View {
        HStack(spacing: Theme.iconLabelSpacing) {
            Image(systemName: "keyboard.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 18, height: 13)
                .foregroundStyle(Theme.keyboardColor)
                .symbolEffect(.bounce, options: .nonRepeating, value: wiggle)
            Text(layout)
                .font(.system(size: Theme.labelSize, weight: .semibold))
                .foregroundStyle(Theme.labelColor)
                .stableMinWidth()
        }
        .glassPill()
        .onChange(of: layout) { wiggle.toggle() }
    }
}
