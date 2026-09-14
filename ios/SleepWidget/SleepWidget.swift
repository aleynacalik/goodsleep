import WidgetKit
import SwiftUI

private let appGroup = "group.com.aleynacalik.goodsleep"

struct SleepEntry: TimelineEntry {
    let date: Date
    let babyName: String
    let isSleeping: Bool
    let sleepDuration: String
}

struct SleepProvider: TimelineProvider {
    private var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    func placeholder(in context: Context) -> SleepEntry {
        SleepEntry(date: Date(), babyName: "Bebek", isSleeping: false, sleepDuration: "")
    }

    func getSnapshot(in context: Context, completion: @escaping (SleepEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SleepEntry>) -> Void) {
        let next = Calendar.current.date(byAdding: .minute, value: 1, to: Date())!
        completion(Timeline(entries: [makeEntry()], policy: .after(next)))
    }

    private func makeEntry() -> SleepEntry {
        SleepEntry(
            date: Date(),
            babyName: defaults?.string(forKey: "babyName") ?? "Bebek",
            isSleeping: defaults?.bool(forKey: "isSleeping") ?? false,
            sleepDuration: defaults?.string(forKey: "sleepDuration") ?? ""
        )
    }
}

struct SleepWidgetView: View {
    var entry: SleepEntry

    private let purple = Color(red: 0.70, green: 0.61, blue: 0.85)
    private let darkPurple = Color(red: 0.51, green: 0.44, blue: 0.66)
    private let textDark = Color(red: 0.17, green: 0.13, blue: 0.23)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 9))
                    .foregroundColor(purple)
                Text("Tatlı Rüyalar")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(purple)
            }
            Spacer()
            Text(entry.babyName)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(textDark)
            HStack(spacing: 5) {
                Circle()
                    .fill(entry.isSleeping ? darkPurple : purple)
                    .frame(width: 7, height: 7)
                if entry.isSleeping {
                    Text(entry.sleepDuration)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(textDark)
                    Text("uyuyor")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                } else {
                    Text("Uyanık")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(textDark)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct SleepWidget: Widget {
    let kind = "SleepWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SleepProvider()) { entry in
            if #available(iOS 17.0, *) {
                SleepWidgetView(entry: entry)
                    .containerBackground(.background, for: .widget)
            } else {
                SleepWidgetView(entry: entry)
                    .background(Color(.systemBackground))
            }
        }
        .configurationDisplayName("Tatlı Rüyalar")
        .description("Bebeğinizin uyku durumunu takip edin.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
