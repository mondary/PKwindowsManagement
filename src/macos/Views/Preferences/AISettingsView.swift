import SwiftUI

struct AISettingsView: View {
    @StateObject private var models = LocalAIModelManager.shared
    @State private var confirmDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: "cpu")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.accentColor)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(localizedString("Laya — shared local model"))
                                .font(.headline)
                            Text(localizedString("convaiinnovations/laya · three checkpoints"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        statusBadge
                    }

                    Divider()

                    HStack {
                        Label(models.modelInstalled ? localizedString("Model downloaded") : localizedString("Model not downloaded"), systemImage: models.modelInstalled ? "checkmark.circle.fill" : "circle.dashed")
                            .foregroundStyle(models.modelInstalled ? .green : .secondary)
                        Spacer()
                        Text(models.modelInstalled ? models.modelSizeLabel : "≈ 2.2 GB + runtime")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 10) {
                        if !models.modelInstalled {
                            Button {
                                models.downloadModel()
                            } label: {
                                Label(localizedString("Download shared model"), systemImage: "arrow.down.circle")
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(models.isBusy)
                        }

                        if models.serverReady || models.serverLoading {
                            Button {
                                models.stopServer()
                            } label: {
                                Label(localizedString("Unload model"), systemImage: "stop.circle")
                            }
                            .disabled(models.isBusy || models.serverLoading)
                        } else if models.modelInstalled {
                            Button {
                                models.startServer()
                            } label: {
                                Label(localizedString("Load model"), systemImage: "play.circle")
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(models.isBusy)
                        }

                        Spacer()

                        if models.modelInstalled {
                            Button(role: .destructive) {
                                confirmDelete = true
                            } label: {
                                Label(localizedString("Delete shared model"), systemImage: "trash")
                            }
                            .disabled(models.isBusy)
                        }
                    }

                    if models.isBusy {
                        ProgressView(localizedString("Working…"))
                            .controlSize(.small)
                    }

                    Text(localizedString("Model storage is shared by PK apps in the Hugging Face cache. The first setup also installs the Python runtime. Deleting the model removes shared weights for all apps; the next download will fetch them again."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5))

                VStack(alignment: .leading, spacing: 8) {
                    Label(localizedString("Launchpad categorization"), systemImage: "square.grid.2x2")
                        .font(.headline)
                    Text(localizedString("Launchpad uses built-in rules and manual per-app overrides. Tests showed that Laya cannot reliably categorize an app from its name alone (18–21% accuracy), so it is not used for this task."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                if let error = models.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }
            .padding(24)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .onAppear { models.refresh() }
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            models.refresh()
        }
        .alert(localizedString("Delete shared Laya model?"), isPresented: $confirmDelete) {
            Button(localizedString("Cancel"), role: .cancel) {}
            Button(localizedString("Delete from shared cache"), role: .destructive) {
                models.deleteModel()
            }
        } message: {
            Text(localizedString("This deletes about 2.2 GB of Laya weights from the Hugging Face cache for every PK app. This cannot be undone."))
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 38, height: 38)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(localizedString("Local AI"))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text(localizedString("Manage shared local model weights."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var statusBadge: some View {
        if models.serverReady {
            Label(localizedString("Loaded"), systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption.weight(.medium))
        } else if models.serverLoading {
            Label(localizedString("Loading"), systemImage: "hourglass")
                .foregroundStyle(.orange)
                .font(.caption.weight(.medium))
        } else {
            Label(localizedString("Unloaded"), systemImage: "circle")
                .foregroundStyle(.secondary)
                .font(.caption.weight(.medium))
        }
    }
}
