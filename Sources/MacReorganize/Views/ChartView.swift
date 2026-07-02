import Charts
import SwiftUI

// MARK: - Data models

struct ChartSlice: Identifiable {
    let id: String
    let label: String
    let count: Int
    let bytes: Int64
    let color: Color
}

// MARK: - Main chart view (adapts to overview vs category selection)

struct FileDistributionChart: View {
    let files: [FileItem]
    let selection: SidebarSelection

    @State private var highlighted: String? = nil

    private var slices: [ChartSlice] {
        switch selection {
        case .overview, .largeFiles, .duplicates:
            return categorySlices(from: files)
        case .category:
            return extensionSlices(from: files)
        }
    }

    var body: some View {
        if slices.isEmpty {
            Text("No data")
                .font(.system(size: 11))
                .foregroundStyle(Color.obsidianSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else {
            DonutChart(slices: slices, highlighted: $highlighted, totalCount: files.count)
        }
    }

    // MARK: - Slice builders

    private func categorySlices(from files: [FileItem]) -> [ChartSlice] {
        let grouped = Dictionary(grouping: files, by: \.effectiveCategory)
        return FileCategory.allCases.compactMap { cat -> ChartSlice? in
            let items = grouped[cat] ?? []
            guard !items.isEmpty else { return nil }
            return ChartSlice(
                id: cat.rawValue,
                label: cat.rawValue,
                count: items.count,
                bytes: items.reduce(0) { $0 + $1.size },
                color: cat.chartColor
            )
        }
        .sorted { $0.count > $1.count }
    }

    private func extensionSlices(from files: [FileItem]) -> [ChartSlice] {
        let grouped = Dictionary(grouping: files) { file -> String in
            let ext = file.url.pathExtension.lowercased()
            return ext.isEmpty ? "no extension" : ext
        }
        let palette = Color.chartPalette
        return grouped
            .map { ($0.key, $0.value) }
            .sorted { $0.1.count > $1.1.count }
            .enumerated()
            .map { idx, pair in
                ChartSlice(
                    id: pair.0,
                    label: ".\(pair.0)",
                    count: pair.1.count,
                    bytes: pair.1.reduce(0) { $0 + $1.size },
                    color: palette[idx % palette.count]
                )
            }
    }
}

// MARK: - Custom Canvas donut (macOS 13 compatible)

struct DonutChart: View {
    let slices: [ChartSlice]
    @Binding var highlighted: String?
    let totalCount: Int

    var body: some View {
        Canvas { ctx, size in
            let total = slices.reduce(0) { $0 + $1.count }
            guard total > 0 else { return }

            let cx = size.width / 2
            let cy = size.height / 2
            let outerR = min(cx, cy) - 2
            let innerR = outerR * 0.58
            let gap: Double = 0.02

            var startAngle = Angle.degrees(-90)

            for slice in slices {
                let fraction = Double(slice.count) / Double(total)
                let sweep = Angle.radians(fraction * 2 * .pi - gap)
                let endAngle = startAngle + sweep

                let isHL = highlighted == nil || highlighted == slice.id
                let scale: CGFloat = (highlighted == slice.id) ? 1.04 : 1.0

                var path = Path()
                path.addArc(center: CGPoint(x: cx, y: cy),
                            radius: outerR * scale,
                            startAngle: startAngle + Angle.radians(gap / 2),
                            endAngle: endAngle,
                            clockwise: false)
                path.addArc(center: CGPoint(x: cx, y: cy),
                            radius: innerR * scale,
                            startAngle: endAngle,
                            endAngle: startAngle + Angle.radians(gap / 2),
                            clockwise: true)
                path.closeSubpath()

                ctx.fill(path, with: .color(slice.color.opacity(isHL ? 1 : 0.25)))

                startAngle = endAngle + Angle.radians(gap)
            }
        }
        .overlay {
            // Centre label
            VStack(spacing: 0) {
                Text("\(totalCount)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("FILES")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.obsidianOutline)
                    .tracking(0.5)
            }
        }
    }
}

// MARK: - Colour palettes

extension FileCategory {
    var chartColor: Color {
        switch self {
        case .images:       return Color.obsidianPrimaryContainer
        case .documents:    return Color.obsidianPrimary
        case .audio:        return Color.obsidianPrimaryFixed
        case .video:        return Color.obsidianInversePrimary
        case .archives:     return Color.obsidianOutline
        case .code:         return Color.obsidianOnSurfaceVariant
        case .applications: return Color.obsidianSecondary
        case .other:        return Color.obsidianTertiary
        }
    }
}

extension Color {
    static let chartPalette: [Color] = [
        Color.obsidianPrimaryContainer,
        Color.obsidianPrimary,
        Color.obsidianPrimaryFixed,
        Color.obsidianInversePrimary,
        Color.obsidianOutline,
        Color.obsidianOnSurfaceVariant,
        Color.obsidianSecondary,
        Color.obsidianTertiary,
        Color(hex: "#ffdbcc"),
        Color(hex: "#dfc0b2")
    ]
}
