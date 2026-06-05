import AppKit
import SwiftUI

struct CleanView: View {
    @Environment(CleanModel.self) var service
    @State private var showConfirmation = false
    @AppStorage("dryRunMode") private var dryRunMode = false
    @AppStorage("confirmBeforeClean") private var confirmBeforeClean = true

    var body: some View {
        VStack(spacing: 0) {
            if dryRunMode {
                dryRunBanner
            }

            // Global cleaning progress banner
            if service.cleaningCategory != nil {
                cleaningBanner
            }

            ScrollView {
                VStack(spacing: 12) {
                    headerCard
                    contentArea
                }
                .padding()
            }
        }
        .task {
            await service.scan()
        }
        .alert(dryRunMode ? LanguageManager.tr("Confirm Preview") : LanguageManager.tr("Confirm Clean"), isPresented: $showConfirmation) {
            Button(LanguageManager.tr("Cancel"), role: .cancel) {}
            Button(dryRunMode ? LanguageManager.tr("Preview") : LanguageManager.tr("Clean"), role: dryRunMode ? .none : .destructive) {
                Task { await runCleanAll() }
            }
        } message: {
            if dryRunMode {
                Text(LanguageManager.tr("Preview system cleanup? No files will be deleted."))
            } else {
                Text(LanguageManager.tr("Clean system caches, logs, and temporary files? This cannot be undone."))
            }
        }
    }

    private var dryRunBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "eye")
                .font(.caption2)
            Text(LanguageManager.tr("DRY RUN"))
                .font(.system(size: 11, weight: .semibold))
            Text(LanguageManager.tr("— preview only, no files will be deleted"))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.yellow.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    private var cleaningBanner: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text(dryRunMode ? LanguageManager.tr("Previewing...") : LanguageManager.tr("Cleaning..."))
                .font(.system(size: 12, weight: .medium))
            Text(LanguageManager.tr("Please wait, this may take a while"))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    // MARK: - Header

    private var headerCard: some View {
        MoleHeroPanel(
            eyebrow: LanguageManager.tr("Maintenance"),
            title: LanguageManager.tr("Clean"),
            subtitle: LanguageManager.tr("Sweep caches, logs, browser leftovers, and temporary files without making the screen feel clinical."),
            symbol: "sparkles"
        ) {
            VStack(alignment: .trailing, spacing: 10) {
                if let cleanedBytes = service.lastCleanedBytes {
                    MoleMetricBadge(
                        title: cleanedBytes == 0 ? LanguageManager.tr("Status") : LanguageManager.tr("Freed"),
                        value: cleanedBytes == 0 ? LanguageManager.tr("Already clean") : MetricsFormatter.humanBytes(cleanedBytes),
                        systemImage: cleanedBytes == 0 ? "checkmark.circle" : "leaf.fill",
                        tint: cleanedBytes == 0 ? .secondary : .green
                    )
                }

                HStack(spacing: 10) {
                    Button {
                        Task { await service.scan() }
                    } label: {
                        Label(LanguageManager.tr("Scan"), systemImage: "arrow.clockwise")
                    }
                    .disabled(service.isScanning)

                    Button {
                        if confirmBeforeClean {
                            showConfirmation = true
                        } else {
                            Task { await runCleanAll() }
                        }
                    } label: {
                        let text = dryRunMode ? LanguageManager.tr("Preview") : LanguageManager.tr("Clean All")
                        let icon = dryRunMode ? "eye" : "trash"
                        Label(text, systemImage: icon)
                    }
                    .disabled(service.isScanning || service.cleaningCategory != nil)
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentArea: some View {
        if let error = service.errorMessage {
            GroupBox {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            }
        }

        // Show what will be cleaned
        GroupBox(LanguageManager.tr("Ready to Clean")) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    cleanItemRow(icon: "folder.badge.gearshape", text: LanguageManager.tr("System caches and logs"))
                    cleanItemRow(icon: "safari", text: LanguageManager.tr("Browser caches"))
                    cleanItemRow(icon: "hammer", text: LanguageManager.tr("Development tool caches"))
                    cleanItemRow(icon: "app.badge", text: LanguageManager.tr("Application caches"))
                    cleanItemRow(icon: "trash", text: LanguageManager.tr("Trash and temporary files"))
                }
                .font(.callout)

                Text(LanguageManager.tr("Active applications and protected files will be skipped for safety."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
    }

    private func cleanItemRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(.secondary)
            Text(text)
        }
    }

    private func runCleanAll() async {
        // Run mole clean without any category filter - it will clean everything
        await service.cleanAll(dryRun: dryRunMode)
    }
}
