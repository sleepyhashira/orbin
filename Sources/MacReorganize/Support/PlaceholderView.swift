import SwiftUI

struct PlaceholderView: View {
    let title: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 32))
                .foregroundStyle(Color.obsidianSecondary.opacity(0.6))
            Text(title)
                .font(.appBodyMedium())
                .foregroundStyle(Color.obsidianSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
