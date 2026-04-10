import SwiftUI
import Monitors

/// A warning pill shown in the bar when the config file has an error.
/// Hover to see the full error description.
struct ConfigErrorView: View {
    let error: ConfigError

    var body: some View {
        HStack(spacing: Theme.iconLabelSpacing) {
            Image(systemName: "exclamationmark.triangle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: Theme.iconSize, height: Theme.iconSize)
                .foregroundStyle(Color.yellow)
            Text("Config error")
                .font(.system(size: Theme.labelSize, weight: .semibold))
                .foregroundStyle(Color.yellow)
        }
        .glassPill()
        .help(error.localizedDescription ?? String(describing: error))
    }
}
