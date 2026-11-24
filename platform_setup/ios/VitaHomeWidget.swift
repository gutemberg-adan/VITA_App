import WidgetKit
import SwiftUI

private let vitaGroup = "group.com.vita.monitoramento"

struct VitaEntry: TimelineEntry {
    let date: Date
    let temperature: String
    let heartRate: String
    let spo2: String
    let updatedAt: String
    let connected: Bool
    let dataStatus: String
}

struct VitaProvider: TimelineProvider {
    func placeholder(in context: Context) -> VitaEntry {
        VitaEntry(date: .now, temperature: "36,8 °C", heartRate: "72 bpm", spo2: "98%", updatedAt: "--", connected: false, dataStatus: "Dados demonstrativos")
    }
    func getSnapshot(in context: Context, completion: @escaping (VitaEntry) -> Void) {
        completion(loadEntry())
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<VitaEntry>) -> Void) {
        let entry = loadEntry()
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60))))
    }
    private func loadEntry() -> VitaEntry {
        let defaults = UserDefaults(suiteName: vitaGroup)
        return VitaEntry(date: .now,
            temperature: defaults?.string(forKey: "temperature") ?? "-- °C",
            heartRate: defaults?.string(forKey: "heartRate") ?? "-- bpm",
            spo2: defaults?.string(forKey: "spo2") ?? "-- %",
            updatedAt: defaults?.string(forKey: "updatedAt") ?? "--",
            connected: defaults?.bool(forKey: "connected") ?? false,
            dataStatus: defaults?.string(forKey: "dataStatus") ?? "Dados demonstrativos")
    }
}

struct VitaHomeWidgetView: View {
    var entry: VitaEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("V.I.T.A. · MEDIÇÕES").font(.caption).bold().foregroundStyle(Color(red: 0.10, green: 0.47, blue: 0.93))
            HStack {
                metric("Temperatura", entry.temperature)
                metric("Frequência", entry.heartRate)
                metric("SpO₂", entry.spo2)
            }
            Text(entry.dataStatus)
                .font(.caption2).foregroundStyle(.secondary)
            Text("Atualizado: \(entry.updatedAt)").font(.system(size: 9)).foregroundStyle(.secondary)
        }.padding().background(Color(.systemBackground))
    }
    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 9)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 15, weight: .bold)).minimumScaleFactor(0.7).lineLimit(1)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

@main
struct VitaHomeWidget: Widget {
    let kind = "VitaHomeWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VitaProvider()) { entry in
            VitaHomeWidgetView(entry: entry)
        }
        .configurationDisplayName("Medições V.I.T.A.")
        .description("Acompanhe as últimas medições de sinais vitais.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
