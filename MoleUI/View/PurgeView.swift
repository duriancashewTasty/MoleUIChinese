import AppKit
import SwiftUI

struct PurgeView: View {
    @Environment(PurgeModel.self) var service

    private var totalReclaimable: UInt64 {
        service.targets.reduce(0) { $0 + $1.sizeBytes }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                headerCard
                contentArea
            }
            .padding()
        }
        .task {
            await service.scan()
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        MoleHeroPanel(
            eyebrow: LanguageManager.tr("Projects"),
            title: LanguageManager.tr("Purge"),
            subtitle: LanguageManager.tr("Clear build artifacts and dependency caches from project directories without turning every repo into a guessing game."),
            symbol: "folder.badge.minus"
        ) {
            VStack(alignment: .trailing, spacing: 10) {
                MoleMetricBadge(
                    title: LanguageManager.tr("Reclaimable"),
                    value: MetricsFormatter.humanBytes(totalReclaimable),
                    systemImage: "shippingbox.circle.fill",
                    tint: .orange
                )

                HStack(spacing: 10) {
                    Button {
                        openPathsEditorWindow()
                    } label: {
                        Label(LanguageManager.tr("Edit Paths"), systemImage: "slider.horizontal.3")
                    }

                    Button {
                        Task { await service.scan() }
                    } label: {
                        Label(LanguageManager.tr("Scan"), systemImage: "arrow.clockwise")
                    }
                    .disabled(service.isScanning)
                }
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentArea: some View {
        if service.isScanning, service.targets.isEmpty {
            GroupBox {
                VStack(spacing: 8) {
                    ProgressView("Scanning project directories...")
                        .controlSize(.regular)
                    Text(LanguageManager.tr("Looking for build artifacts"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }
        } else if let error = service.errorMessage {
            GroupBox {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            }
        }

        if service.targets.isEmpty, !service.isScanning {
            GroupBox {
                Text(LanguageManager.tr("No build artifacts found in scan paths."))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
        }

        scanPathsCard

        if !service.targets.isEmpty {
            ForEach(service.targets) { target in
                targetRow(target)
            }
        }
    }

    // MARK: - Target Row

    private func targetRow(_ target: PurgeTarget) -> some View {
        let isCleaning = service.cleaningTarget == target.id
        let isCompleted = service.completedTargets.contains(target.id)

        return GroupBox {
            HStack(spacing: 10) {
                Image(systemName: iconForArtifact(target.artifactName))
                    .frame(width: 20)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 1) {
                    Text(target.projectName)
                        .fontWeight(.medium)
                    Text(target.artifactName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 160, alignment: .leading)

                Spacer()

                if target.isRecent {
                    Text("< 7d")
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                } else {
                    Text("\(target.ageDays)d ago")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(MetricsFormatter.humanBytes(target.sizeBytes))
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.medium)
                    .frame(width: 80, alignment: .trailing)

                if isCleaning {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 16, height: 16)
                        .frame(width: 60)
                } else if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .frame(width: 60)
                } else {
                    Button(LanguageManager.tr("Purge")) {
                        Task { await service.deleteTarget(target) }
                    }
                    .disabled(service.cleaningTarget != nil)
                    .frame(width: 60)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func iconForArtifact(_ name: String) -> String {
        switch name {
        case "node_modules": "shippingbox"
        case "target", "build", "dist", ".output", "zig-out", "obj", ".build":
            "hammer"
        case "venv", ".venv", ".tox", ".nox":
            "terminal"
        case "DerivedData": "xcode"
        case "Pods": "puzzlepiece"
        case ".gradle": "gearshape.2"
        case "__pycache__", ".pytest_cache", ".mypy_cache", ".ruff_cache":
            "memorychip"
        case ".next", ".nuxt", ".angular", ".svelte-kit", ".astro":
            "globe"
        case "coverage": "chart.bar"
        default: "folder"
        }
    }

    // MARK: - Paths

    private var scanPathsCard: some View {
        GroupBox(LanguageManager.tr("Scan Paths")) {
            VStack(alignment: .leading, spacing: 6) {
                Text(LanguageManager.tr("Default paths plus ~/Library/Application Support/MoleUI/purge_paths are used."))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 2)
        }
    }

    private func openPathsEditorWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 640),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Edit Scan Paths"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isOpaque = true
        window.backgroundColor = NSColor.windowBackgroundColor
        window.center()
        window.contentView = NSHostingView(
            rootView: PurgePathsEditorView(window: window, service: service)
        )
        window.makeKeyAndOrderFront(nil)
    }
}

// MARK: - Purge Paths Editor

struct PurgePathsEditorView: View {
    let window: NSWindow?
    let service: PurgeModel
    @State private var pathsText: String = ""
    @State private var errorMessage: String?

    init(window: NSWindow? = nil, service: PurgeModel) {
        self.window = window
        self.service = service
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top spacer for window controls (macOS titlebar height is ~52px)
            Color.clear
                .frame(height: 52)

            // Header
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 48, height: 48)
                    .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 6) {
                    Text("PROJECTS".localizedUppercase)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .tracking(0.8)

                    Text(LanguageManager.tr("Edit Scan Paths"))
                        .font(.system(size: 24, weight: .bold))

                    Text(LanguageManager.tr("One path per line. Mole UI merges these with the built-in defaults before each purge scan."))
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Button(LanguageManager.tr("Done")) {
                    savePaths()
                    window?.close()
                    Task { await service.scan() }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)

                Text(LanguageManager.tr("Add one path per line. Use ~ for home directory (half-width tilde, not ～)."))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                Text(LanguageManager.tr("Default paths: ~/www, ~/dev, ~/Projects, ~/GitHub, ~/Code, ~/Workspace, ~/Repos, ~/Development"))
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            loadPaths()
        }
    }

    private func loadPaths() {
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else { return }

        let configPath = appSupport.appendingPathComponent("MoleUI/purge_paths")
        pathsText = (try? String(contentsOf: configPath, encoding: .utf8)) ?? ""
    }

    private func savePaths() {
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            errorMessage = LanguageManager.tr("Failed to access Application Support directory")
            return
        }

        let moleUIDir = appSupport.appendingPathComponent("MoleUI")
        let configPath = moleUIDir.appendingPathComponent("purge_paths")

        // Normalize paths: replace full-width tilde with half-width
        let normalizedText = pathsText
            .replacingOccurrences(of: "～", with: "~")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            try FileManager.default.createDirectory(at: moleUIDir, withIntermediateDirectories: true)
            try normalizedText.write(to: configPath, atomically: true, encoding: .utf8)
            errorMessage = nil
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }
}
