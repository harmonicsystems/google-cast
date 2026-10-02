import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var cast: CastController
    @State private var tempo = 96
    @State private var key = "C"
    @State private var repeatForever = true

    private var track: Track { Library.track(key: key, tempo: tempo) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Tempo", selection: $tempo) {
                        ForEach(Library.tempos, id: \.self) { Text("\($0) BPM").tag($0) }
                    }
                    Picker("Key", selection: $key) {
                        ForEach(Library.keys, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu)
                    Toggle("Repeat", isOn: $repeatForever)
                } header: {
                    Text(Library.setup)
                } footer: {
                    Text("Three-minute renders, AAC. Repeat loads the file as a one-item queue so the speaker loops it.")
                }

                Section {
                    Button {
                        cast.play(track, repeatForever: repeatForever)
                    } label: {
                        Label("Play on speaker", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!cast.isConnected)

                    if cast.isConnected && cast.nowPlayingTitle != nil {
                        HStack {
                            Button { cast.pause() } label: { Label("Pause", systemImage: "pause.fill") }
                                .disabled(cast.playerState != .playing)
                            Spacer()
                            Button { cast.resume() } label: { Label("Resume", systemImage: "play") }
                                .disabled(cast.playerState != .paused)
                            Spacer()
                            Button(role: .destructive) { cast.stop() } label: { Label("Stop", systemImage: "stop.fill") }
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                    }
                } header: {
                    Text(track.title)
                }

                Section("Speaker") {
                    if let name = cast.deviceName {
                        LabeledContent("Connected to", value: name)
                        LabeledContent("State", value: cast.playerState.label)
                        if let title = cast.nowPlayingTitle {
                            LabeledContent("Now playing", value: title)
                        }
                    } else {
                        Text("Tap the Cast button to pick a speaker.")
                            .foregroundStyle(.secondary)
                    }
                    if let error = cast.lastError {
                        Text(error).foregroundStyle(.red).font(.footnote)
                    }
                }
            }
            .navigationTitle("BackTrack Cast")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    CastButton().frame(width: 28, height: 28)
                }
            }
        }
    }
}
