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

    private var chartTitle: String {
        switch selection {
        case .overview:          return "File Types"
        case .category(let cat): return "\(cat.rawValue) – by Extension"
        case .largeFiles:        return "Large Files by Type"
        case .duplicates:        return "Duplicates by Type"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(chartTitle)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            if slices.isEmpty {
                Text("No data")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 140, alignment: .center)
            } else {
                HStack(alignment: .center, spacing: 16) {
                    // ── Donut chart (Canvas-based, works on macOS 13+) ──
                    DonutChart(slices: slices, highlighted: $highlighted, totalCount: files.count)
                        .frame(width: 140, height: 140)

                    // ── Legend ──
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(slices.prefix(8)) { slice in
                            HStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(slice.color)
                                    .frame(width: 8, height: 8)
                                Text(slice.label)
                                    .font(.caption)
                                    .lineLimit(1)
                                Spacer(minLength: 4)
                                Text("\(slice.count)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            .opacity(highlighted == nil || highlighted == slice.id ? 1 : 0.35)
                            .contentShape(Rectangle())
                            .onHover { inside in
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    highlighted = inside ? slice.id : nil
                                }
                            }
                        }
                        if slices.count > 8 {
                            Text("+ \(slices.count - 8) more")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
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
            let innerR = outerR * 0.52
            let gap: Double = 0.018   // radians between slices

            var startAngle = Angle.degrees(-90)

            for slice in slices {
                let fraction = Double(slice.count) / Double(total)
                let sweep = Angle.radians(fraction * 2 * .pi - gap)
                let endAngle = startAngle + sweep

                let isHL = highlighted == nil || highlighted == slice.id
                let scale: CGFloat = (highlighted == slice.id) ? 1.06 : 1.0

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

                ctx.fill(path, with: .color(slice.color.opacity(isHL ? 1 : 0.3)))

                // Percentage label on large-enough slices
                if fraction >= 0.12 {
                    let midAngle = startAngle + Angle.radians(fraction * .pi - gap / 2)
                    let labelR = (outerR + innerR) / 2 * scale
                    let lx = cx + labelR * cos(midAngle.radians)
                    let ly = cy + labelR * sin(midAngle.radians)
                    let pct = "\(Int(fraction * 100))%"
                    ctx.draw(
                        Text(pct)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.white),
                        at: CGPoint(x: lx, y: ly)
                    )
                }

                startAngle = endAngle + Angle.radians(gap)
            }
        }
        .overlay {
            // Centre label
            VStack(spacing: 0) {
                Text("\(totalCount)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Text("files")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Colour palettes

extension FileCategory {
    var chartColor: Color {
        switch self {
        case .images:       return Color(hue: 0.58, saturation: 0.70, brightness: 0.85)
        case .documents:    return Color(hue: 0.12, saturation: 0.75, brightness: 0.90)
        case .audio:        return Color(hue: 0.82, saturation: 0.60, brightness: 0.85)
        case .video:        return Color(hue: 0.95, saturation: 0.65, brightness: 0.85)
        case .archives:     return Color(hue: 0.38, saturation: 0.55, brightness: 0.75)
        case .code:         return Color(hue: 0.52, saturation: 0.65, brightness: 0.80)
        case .applications: return Color(hue: 0.07, saturation: 0.70, brightness: 0.85)
        case .other:        return Color(hue: 0.00, saturation: 0.00, brightness: 0.55)
        }
    }
}

extension Color {
    static let chartPalette: [Color] = [
        Color(hue: 0.58, saturation: 0.70, brightness: 0.85),
        Color(hue: 0.12, saturation: 0.75, brightness: 0.90),
        Color(hue: 0.82, saturation: 0.60, brightness: 0.85),
        Color(hue: 0.38, saturation: 0.55, brightness: 0.75),
        Color(hue: 0.95, saturation: 0.65, brightness: 0.85),
        Color(hue: 0.52, saturation: 0.65, brightness: 0.80),
        Color(hue: 0.07, saturation: 0.70, brightness: 0.85),
        Color(hue: 0.68, saturation: 0.55, brightness: 0.80),
        Color(hue: 0.25, saturation: 0.60, brightness: 0.80),
        Color(hue: 0.45, saturation: 0.65, brightness: 0.85),
    ]
}
