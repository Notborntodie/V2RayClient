import SwiftUI

struct StatusCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    let subtitle: String
    @EnvironmentObject var appFont: AppFont

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(appFont.title3)
                    .foregroundColor(iconColor)
                Text(title)
                    .font(appFont.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            Text(value)
                .font(appFont.title2)
            Text(subtitle)
                .font(appFont.caption)
                .foregroundColor(.secondary)
        }
        .padding(20)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}
