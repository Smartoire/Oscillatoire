import SwiftUI

/// About the app: credits, licences and what the numbers mean.
struct InfoView: View {
    private var version: String {
        let info = Bundle.main.infoDictionary
        return "\(info?["CFBundleShortVersionString"] as? String ?? "1.0") (\(info?["CFBundleVersion"] as? String ?? "1"))"
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Image("BrandMark").resizable().frame(width: 72, height: 72).clipShape(RoundedRectangle(cornerRadius: 16))
                    Text("Brainwave").font(.largeTitle.bold())
                    Text("Formerly Oscillatoire").font(.caption).foregroundStyle(.secondary)
                    Text("See your brain activity live with a Muse EEG headband.").foregroundStyle(.secondary)
                    Text("Version \(version)").font(.caption).foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }

            Section("Created by") {
                credit("Vahid Ghafarpour", "Developer", systemImage: "person.fill", url: URL(string: "https://vahid.ghafarpour.com/"))
                credit("Smartoire", "Development", systemImage: "building.2.fill", url: URL(string: "https://smartoire.com/"))
                credit("BC+AI Lifescience", "Research and life-science partner", systemImage: "cross.case.fill", url: URL(string: "https://bc-ai.ca/communities/life-sciences-ai"))
            }

            Section {
                Text("Brainwave is open source under the MIT License: free to use, change and share, as long as the copyright notice is kept. The Muse SDK is not included in this project and is not distributed with it.")
            } header: {
                Text("Open source")
            }

            Section {
                Text("Brainwave has no accounts and sends nothing to a server. Your captures and history stay on this device, and you choose when to share a file.")
            } header: {
                Text("Your data")
            }

            Section("Acknowledgements") {
                credit("Muse SDK", "© Interaxon Inc. Proprietary, used under licence. Not part of the open-source code.", systemImage: "headphones")
                credit("“Brain Areas” model", "By Versal on Sketchfab, licensed CC BY 4.0. The brain image in this app is made from it.", systemImage: "brain")
                credit("Engagement index", "Pope, Bogart & Bartolome (1995), Biological Psychology 40.", systemImage: "book.closed")
            }

            Section {
                Text("Brainwave is for education and curiosity. It is not a medical device, not medical advice, and not for research or clinical use. It does not diagnose, treat or monitor any condition. Scores compare you with your own recent baseline and are affected by movement, blinking and how well the sensors touch your skin.")
                    .font(.callout).foregroundStyle(.secondary)
            } header: {
                Text("Not a medical device")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .navigationTitle("Info")
    }

    /// A credit row. With a link, tapping it opens the website.
    @ViewBuilder
    private func credit(_ title: LocalizedStringKey, _ detail: LocalizedStringKey, systemImage: String, url: URL? = nil) -> some View {
        let row = Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: systemImage).foregroundStyle(Color.accentColor)
        }
        .accessibilityElement(children: .combine)
        if let url {
            Link(destination: url) { row }
        } else {
            row
        }
    }
}
