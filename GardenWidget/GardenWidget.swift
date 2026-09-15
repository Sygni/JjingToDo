//
//  GardenWidget.swift
//  GardenWidget
//
//  홈 화면에 이번 주 정원을 보여주는 위젯.
//  Core Data를 열지 않고, 앱이 App Group에 남긴 이번 주 요약(GardenSnapshot)만 읽는다.
//  화단은 앱의 주간 뷰와 같은 WeekPlotView로 그린다.
//

import WidgetKit
import SwiftUI

struct GardenEntry: TimelineEntry {
    let date: Date
    let weekStart: Date
    let days: [DayGarden]
}

extension GardenEntry {
    /// 위젯 갤러리 미리보기용
    static var sample: GardenEntry {
        let start = GardenCalendar.weekStart(containing: Date())
        let kinds: [[PlantKind]] = [
            [.flower, .sprout], [.tree], [], [.mushroom, .sprout, .sprout], [.flower], [], [.sprout]
        ]
        let days = zip(GardenCalendar.weekDays(from: start), kinds).map { date, plantKinds in
            DayGarden(date: date, plants: plantKinds.map { PlantedItem(kind: $0) }, moss: 0)
        }
        return GardenEntry(date: Date(), weekStart: start, days: days)
    }
}

struct GardenProvider: TimelineProvider {
    func placeholder(in context: Context) -> GardenEntry {
        .sample
    }

    func getSnapshot(in context: Context, completion: @escaping (GardenEntry) -> Void) {
        completion(context.isPreview ? .sample : currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GardenEntry>) -> Void) {
        // 기록이 바뀌면 앱이 직접 새로고침을 요청한다. 여기서는 주가 바뀌는 순간을 놓치지 않을 만큼만 다시 그린다.
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [currentEntry()], policy: .after(next)))
    }

    private func currentEntry() -> GardenEntry {
        let thisWeek = GardenCalendar.weekStart(containing: Date())
        let emptyWeek = GardenCalendar.weekDays(from: thisWeek).map {
            DayGarden(date: $0, plants: [], moss: 0)
        }
        // 새 주가 시작됐는데 앱을 아직 안 열었으면 지난주 요약이 남아 있다 — 새 주는 빈 화단으로 시작
        guard let snapshot = GardenSnapshot.load(), snapshot.weekStart == thisWeek else {
            return GardenEntry(date: Date(), weekStart: thisWeek, days: emptyWeek)
        }
        return GardenEntry(date: Date(), weekStart: thisWeek, days: snapshot.dayGardens)
    }
}

struct GardenWidgetView: View {
    let entry: GardenEntry
    @Environment(\.widgetFamily) private var family

    private var total: Int { entry.days.reduce(0) { $0 + $1.count } }

    var body: some View {
        switch family {
        case .systemSmall:
            VStack(spacing: 2) {
                WeekPlotView(days: entry.days, seedDate: entry.weekStart)
                Text("이번 주 \(total)포기")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        default:
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("이번 주")
                        .font(.headline)
                    Spacer(minLength: 0)
                    Text("\(total)")
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(hex: "#3E9B6E"))
                    Text("포기 심음")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 78, alignment: .leading)

                WeekPlotView(days: entry.days, seedDate: entry.weekStart)
            }
        }
    }
}

struct GardenWidget: Widget {
    let kind = "GardenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GardenProvider()) { entry in
            GardenWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(.systemBackground)
                }
        }
        .configurationDisplayName("나의 정원")
        .description("이번 주에 심은 식물을 한 화단에 모아 보여줘요.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct GardenWidgetBundle: WidgetBundle {
    var body: some Widget {
        GardenWidget()
    }
}
