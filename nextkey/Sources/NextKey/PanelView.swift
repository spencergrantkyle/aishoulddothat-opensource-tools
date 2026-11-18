import SwiftUI

struct PanelView: View {
    @ObservedObject var session: Session
    let cornerRadius: CGFloat
    let onHeight: (CGFloat) -> Void

    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            inputRow
            if session.phase != .idle {
                Divider().opacity(0.5)
                result
            }
        }
        .frame(width: 680)
        .fixedSize(horizontal: false, vertical: true)
        .background(GeometryReader { g in
            Color.clear.preference(key: HeightKey.self, value: g.size.height)
        })
        .onPreferenceChange(HeightKey.self) { onHeight($0) }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
        )
        .onChange(of: session.focusTick) { focused = true }
        .onAppear { focused = true }
    }

    // MARK: Input

    private var inputRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                Group {
                    if let icon = session.appIcon {
                        Image(nsImage: icon).resizable()
                    } else {
                        Image(systemName: "keyboard").resizable().scaledToFit().foregroundStyle(.secondary)
                    }
                }
                .frame(width: 28, height: 28)

                TextField("", text: $session.query,
                          prompt: Text(session.lastQuestion == nil ?"What do you want to do?" : "Ask a follow-up…"),
                          axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 22))
                    .lineLimit(1...4)
                    .focused($focused)
                    .onSubmit { session.submit() }

                screenshotBadge
            }
            Text(contextLine)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.leading, 40)
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var contextLine: String {
        var s = session.appName
        if let t = session.windowTitle { s += " — \(t)" }
        return s
    }

    @ViewBuilder private var screenshotBadge: some View {
        if let thumb = session.thumbnail {
            Image(nsImage: thumb)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 46, height: 30)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Color.primary.opacity(0.15), lineWidth: 0.5))
                .help("Screenshot attached")
        } else if session.captureFailed {
            Image(systemName: "eye.slash")
                .foregroundStyle(.secondary)
                .help("No screenshot. Allow NextKey in System Settings → Privacy & Security → Screen & System Audio Recording.")
        } else {
            ProgressView().controlSize(.small)
        }
    }

    // MARK: Result

    @ViewBuilder private var result: some View {
        let answer = session.answer
        VStack(alignment: .leading, spacing: 12) {
            if let q = session.lastQuestion {
                Text(q)
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }

            switch session.phase {
            case .failed(let message):
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            case .thinking:
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Reading your screen…").font(.system(size: 13)).foregroundStyle(.secondary)
                }
            default:
                if !answer.keys.isEmpty {
                    KeyChords(spec: answer.keys, size: 30)
                }
                if !answer.what.isEmpty {
                    Text(answer.what)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                if !answer.steps.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("THEN")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.tertiary)
                        ForEach(Array(answer.steps.enumerated()), id: \.offset) { i, step in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text("\(i + 1)")
                                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                                    .foregroundStyle(.tertiary)
                                    .frame(width: 14, alignment: .trailing)
                                KeyChords(spec: step.keys, size: 13)
                                Text(step.text)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }

            if session.phase == .done || session.phase == .streaming {
                Text(session.phase == .done ? "\(session.footer)  ·  ⏎ follow-up  ·  esc close" : " ")
                    .font(.system(size: 10))
                    .foregroundStyle(.quaternary)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

// MARK: - Keycaps

/// Renders "⌃ F2 → ↓ → ⏎" as keycaps. Falls back to plain text when the spec reads like prose.
struct KeyChords: View {
    let spec: String
    let size: CGFloat

    private var chords: [[String]] {
        spec.components(separatedBy: "→").map { chord in
            chord.split(separator: " ").flatMap { token -> [String] in
                let t = String(token)
                return t.count > 1 && t.contains("+") ? t.split(separator: "+").map(String.init) : [t]
            }
        }.filter { !$0.isEmpty }
    }

    private var isProse: Bool {
        let keys = chords.flatMap { $0 }
        return keys.isEmpty || keys.contains { $0.count > 7 } || keys.count > 16
    }

    var body: some View {
        if isProse {
            Text(spec)
                .font(.system(size: size * 0.75, weight: .semibold, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
        } else {
            FlowLayout(spacing: size * 0.25) {
                ForEach(Array(chords.enumerated()), id: \.offset) { i, chord in
                    if i > 0 {
                        Image(systemName: "arrow.right")
                            .font(.system(size: size * 0.5, weight: .medium))
                            .foregroundStyle(.tertiary)
                            .frame(height: size * 1.4)
                    }
                    ForEach(Array(chord.enumerated()), id: \.offset) { _, key in
                        Keycap(label: key, size: size)
                    }
                }
            }
        }
    }
}

struct Keycap: View {
    let label: String
    let size: CGFloat

    var body: some View {
        Text(label)
            .font(.system(size: size, weight: .semibold, design: .rounded))
            .padding(.horizontal, size * 0.35)
            .frame(minWidth: size * 1.4, minHeight: size * 1.4)
            .background(
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .fill(Color.primary.opacity(0.07))
                    .shadow(color: .black.opacity(0.12), radius: 0, x: 0, y: size * 0.04)
            )
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.16), lineWidth: 0.75)
            )
    }
}

/// Left-to-right wrapping layout, vertically centring each row.
struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for i in row.indices {
                let size = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2), proposal: .unspecified)
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row { var indices: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for i in subviews.indices {
            let size = subviews[i].sizeThatFits(.unspecified)
            let extra = rows[rows.count - 1].indices.isEmpty ? size.width : spacing + size.width
            if rows[rows.count - 1].width + extra > width, !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }
            let added = rows[rows.count - 1].indices.isEmpty ? size.width : spacing + size.width
            rows[rows.count - 1].indices.append(i)
            rows[rows.count - 1].width += added
            rows[rows.count - 1].height = max(rows[rows.count - 1].height, size.height)
        }
        return rows
    }
}
