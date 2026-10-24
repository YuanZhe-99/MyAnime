import SwiftUI
import WidgetKit

// "Up next" widget: a 2x2 home-screen widget (systemSmall) and a compact
// lock-screen / StandBy strip (accessoryRectangular, iOS 16+). Both render the
// snapshot that lib/shared/services/home_widget_service.dart writes through
// AppDelegate.swift; the format is documented in
// doc/en-us/features/home-screen-widgets.md.

private let appGroupId = "group.com.yuanzhe.myAnime"
private let snapshotKey = "myanime_widget_snapshot"
private let brand = Color(red: 0x67 / 255, green: 0x3A / 255, blue: 0xB7 / 255)

private let fallbackLabels: [String: String] = [
  "appName": "MyAnime",
  "toWatch": "to watch",
  "today": "Today",
  "caughtUp": "All caught up",
  "noUpdates": "Nothing airs today",
  "next": "Next",
  "episode": "EP {n}",
  "series": "{n} series",
]

// MARK: - Snapshot

/// One episode entry of the snapshot.
struct WidgetEpisode: Decodable, Hashable {
  let id: String
  let t: String
  let e: Int
  let at: Int64
  let w: Bool

  /// Purpose: Return the episode's air instant.
  /// Inputs: None.
  /// Returns: `Date`.
  /// Side effects: None.
  /// Notes: `at` is epoch milliseconds.
  var airDate: Date { Date(timeIntervalSince1970: TimeInterval(at) / 1000) }
}

/// The JSON snapshot the app stores in the App Group.
struct WidgetSnapshot: Decodable {
  let generatedAt: Int64
  let timeZone: String
  let airedUnwatched: Int
  let episodes: [WidgetEpisode]
  let labels: [String: String]

  /// Purpose: Read and decode the stored snapshot.
  /// Inputs: None.
  /// Returns: The snapshot, or nil before the app first wrote one.
  /// Side effects: Reads the App Group `UserDefaults`.
  /// Notes: A decode failure is treated as no snapshot.
  static func load() -> WidgetSnapshot? {
    guard let raw = UserDefaults(suiteName: appGroupId)?.string(forKey: snapshotKey),
      let data = raw.data(using: .utf8)
    else { return nil }
    return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
  }

  /// Purpose: Return the calendar zone that decides what "today" is.
  /// Inputs: None.
  /// Returns: Asia/Tokyo for the JST calendar, otherwise the device zone.
  /// Side effects: None.
  /// Notes: An empty `timeZone` means the device zone.
  var zone: TimeZone {
    timeZone.isEmpty ? .current : (TimeZone(identifier: timeZone) ?? .current)
  }
}

// MARK: - Timeline

/// The widget state at one instant.
struct UpNextEntry: TimelineEntry {
  let date: Date
  let toWatch: Int
  let queue: [WidgetEpisode]
  let todayCount: Int
  let nextUp: WidgetEpisode?
  let labels: [String: String]
  let zone: TimeZone

  /// Purpose: Return a snapshot label, falling back to English.
  /// Inputs: `key`.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: None.
  func label(_ key: String) -> String { labels[key] ?? fallbackLabels[key] ?? key }

  /// Purpose: Format an episode number with the localized template.
  /// Inputs: `number`.
  /// Returns: For example "EP 7" or "第7集".
  /// Side effects: None.
  /// Notes: None.
  func episode(_ number: Int) -> String {
    label("episode").replacingOccurrences(of: "{n}", with: String(number))
  }

  /// Purpose: Format a series count with the localized template.
  /// Inputs: `count`.
  /// Returns: For example "3 series" or "3 部".
  /// Side effects: None.
  /// Notes: None.
  func series(_ count: Int) -> String {
    label("series").replacingOccurrences(of: "{n}", with: String(count))
  }

  /// Purpose: Format an episode's air time in the snapshot zone.
  /// Inputs: `episode`.
  /// Returns: "HH:mm" for today, otherwise a short weekday plus "HH:mm".
  /// Side effects: None.
  /// Notes: Uses the device locale for the weekday name.
  func airTime(_ episode: WidgetEpisode) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = zone
    let formatter = DateFormatter()
    formatter.timeZone = zone
    formatter.locale = .current
    formatter.dateFormat = calendar.isDate(episode.airDate, inSameDayAs: date) ? "HH:mm" : "EEE HH:mm"
    return formatter.string(from: episode.airDate)
  }

  /// Purpose: Evaluate a snapshot at an instant.
  /// Inputs: `snapshot` (nil before the first app launch), `date`.
  /// Returns: `UpNextEntry`.
  /// Side effects: None.
  /// Notes: Mirrors `HomeWidgetService.buildSnapshot`: episodes that aired
  /// after `generatedAt` join the to-watch count and queue.
  static func evaluate(_ snapshot: WidgetSnapshot?, at date: Date) -> UpNextEntry {
    guard let snapshot = snapshot else {
      return UpNextEntry(
        date: date, toWatch: 0, queue: [], todayCount: 0, nextUp: nil, labels: [:], zone: .current)
    }
    let now = Int64(date.timeIntervalSince1970 * 1000)
    let episodes = snapshot.episodes.sorted { $0.at < $1.at }
    let newlyAired = episodes.filter { !$0.w && $0.at > snapshot.generatedAt && $0.at <= now }.count
    var seen = Set<String>()
    let queue = episodes.filter { !$0.w && $0.at <= now && seen.insert($0.id).inserted }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = snapshot.zone
    let todayCount = episodes.filter { calendar.isDate($0.airDate, inSameDayAs: date) }.count
    return UpNextEntry(
      date: date,
      toWatch: snapshot.airedUnwatched + newlyAired,
      queue: queue,
      todayCount: todayCount,
      nextUp: episodes.first { !$0.w && $0.at > now },
      labels: snapshot.labels,
      zone: snapshot.zone)
  }

  /// Sample state for the widget gallery and placeholders.
  static let sample = UpNextEntry(
    date: Date(),
    toWatch: 12,
    queue: [
      WidgetEpisode(id: "a", t: "Frieren", e: 7, at: 0, w: false),
      WidgetEpisode(id: "b", t: "The Apothecary Diaries", e: 3, at: 0, w: false),
    ],
    todayCount: 3,
    nextUp: nil,
    labels: [:],
    zone: .current)
}

/// Builds timelines with an entry at every air time in the next day and at
/// the next midnight, so counts move without the app running.
struct UpNextProvider: TimelineProvider {
  /// Purpose: Return the redacted placeholder entry.
  /// Inputs: `context`.
  /// Returns: `UpNextEntry.sample`.
  /// Side effects: None.
  /// Notes: None.
  func placeholder(in context: Context) -> UpNextEntry { .sample }

  /// Purpose: Return the entry for the widget gallery or a transient view.
  /// Inputs: `context`, `completion`.
  /// Returns: None; calls `completion`.
  /// Side effects: Reads the snapshot.
  /// Notes: The gallery shows sample data until the app has written a snapshot.
  func getSnapshot(in context: Context, completion: @escaping (UpNextEntry) -> Void) {
    let snapshot = WidgetSnapshot.load()
    if context.isPreview && snapshot == nil {
      completion(.sample)
    } else {
      completion(UpNextEntry.evaluate(snapshot, at: Date()))
    }
  }

  /// Purpose: Return the timeline for the next day.
  /// Inputs: `context`, `completion`.
  /// Returns: None; calls `completion`.
  /// Side effects: Reads the snapshot.
  /// Notes: The app also reloads timelines whenever its data changes.
  func getTimeline(in context: Context, completion: @escaping (Timeline<UpNextEntry>) -> Void) {
    let now = Date()
    let snapshot = WidgetSnapshot.load()
    var dates: Set<Date> = [now]
    if let snapshot = snapshot {
      let horizon = now.addingTimeInterval(24 * 3600)
      for episode in snapshot.episodes where episode.airDate > now && episode.airDate <= horizon {
        dates.insert(episode.airDate)
      }
      var calendar = Calendar(identifier: .gregorian)
      calendar.timeZone = snapshot.zone
      if let midnight = calendar.nextDate(
        after: now, matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime)
      {
        dates.insert(midnight)
      }
    }
    let sorted = dates.sorted()
    let entries = sorted.map { UpNextEntry.evaluate(snapshot, at: $0) }
    let reload = max(sorted.last ?? now, now.addingTimeInterval(3600))
    completion(Timeline(entries: entries, policy: .after(reload)))
  }
}

// MARK: - Views

extension View {
  /// Purpose: Mark a view as accented in tinted and lock-screen rendering.
  /// Inputs: None.
  /// Returns: The modified view.
  /// Side effects: None.
  /// Notes: No-op before iOS 16.
  @ViewBuilder func accentable() -> some View {
    if #available(iOSApplicationExtension 16.0, *) {
      widgetAccentable()
    } else {
      self
    }
  }

  /// Purpose: Apply the widget container background on every iOS version.
  /// Inputs: `background`; `padded` — add the system margin before iOS 17.
  /// Returns: The modified view.
  /// Side effects: None.
  /// Notes: iOS 17 requires `containerBackground` and adds margins itself.
  @ViewBuilder func widgetBackground<B: View>(_ background: B, padded: Bool) -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      containerBackground(for: .widget) { background }
    } else {
      padding(padded ? 16 : 0).background(background)
    }
  }
}

/// One title + meta line.
struct EpisodeRow: View {
  let title: String
  let meta: String

  var body: some View {
    HStack(spacing: 4) {
      Text(title).font(.system(size: 12, weight: .medium)).lineLimit(1)
      Spacer(minLength: 2)
      Text(meta).font(.system(size: 11, weight: .semibold)).foregroundColor(brand)
        .lineLimit(1).fixedSize().accentable()
    }
  }
}

/// systemSmall (2x2): header with today's update pill, big to-watch count,
/// and up to two anime from the watch queue (or the next airing episode).
struct UpNextSmallView: View {
  let entry: UpNextEntry

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 4) {
        Image(systemName: "play.circle.fill")
          .font(.system(size: 13, weight: .semibold)).foregroundColor(brand).accentable()
        Text(entry.label("appName"))
          .font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary).lineLimit(1)
        Spacer(minLength: 4)
        Text("\(entry.label("today")) \(entry.todayCount)")
          .font(.system(size: 11, weight: .semibold)).foregroundColor(brand).lineLimit(1)
          .padding(.horizontal, 7).padding(.vertical, 2)
          .background(Capsule().fill(brand.opacity(0.15)))
          .accentable()
      }
      Spacer(minLength: 4)
      if entry.toWatch > 0 {
        Text("\(entry.toWatch)")
          .font(.system(size: 40, weight: .bold, design: .rounded)).foregroundColor(brand)
          .lineLimit(1).minimumScaleFactor(0.6).accentable()
        Text("\(entry.label("toWatch")) · \(entry.series(entry.queue.count))")
          .font(.caption2).foregroundColor(.secondary).lineLimit(1)
      } else {
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 26, weight: .semibold)).foregroundColor(brand).accentable()
        Text(entry.label("caughtUp"))
          .font(.system(size: 15, weight: .semibold)).lineLimit(1).padding(.top, 2)
      }
      Spacer(minLength: 4)
      rows
    }
  }

  @ViewBuilder private var rows: some View {
    if !entry.queue.isEmpty {
      VStack(alignment: .leading, spacing: 3) {
        ForEach(Array(entry.queue.prefix(2)), id: \.self) { episode in
          EpisodeRow(title: episode.t, meta: entry.episode(episode.e))
        }
      }
    } else if let next = entry.nextUp {
      EpisodeRow(title: next.t, meta: entry.airTime(next))
    } else {
      Text(entry.label("noUpdates")).font(.caption2).foregroundColor(.secondary).lineLimit(1)
    }
  }
}

/// accessoryRectangular (the compact strip): count, next title, and episode.
struct UpNextRectangularView: View {
  let entry: UpNextEntry

  var body: some View {
    VStack(alignment: .leading, spacing: 1) {
      HStack(spacing: 4) {
        Image(systemName: "play.circle.fill")
        Text(
          entry.toWatch > 0
            ? "\(entry.toWatch) \(entry.label("toWatch"))" : entry.label("caughtUp")
        )
        .font(.headline).lineLimit(1)
      }
      .accentable()
      if let first = entry.queue.first {
        Text(first.t).font(.system(size: 13, weight: .medium)).lineLimit(1)
        Text("\(entry.episode(first.e)) · \(entry.label("today")) \(entry.todayCount)")
          .font(.caption2).foregroundColor(.secondary).lineLimit(1)
      } else if let next = entry.nextUp {
        Text(next.t).font(.system(size: 13, weight: .medium)).lineLimit(1)
        Text("\(entry.label("next")) \(entry.airTime(next))")
          .font(.caption2).foregroundColor(.secondary).lineLimit(1)
      } else {
        Text(entry.label("noUpdates")).font(.caption2).foregroundColor(.secondary).lineLimit(1)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// Picks the view for the current widget family.
struct UpNextEntryView: View {
  @Environment(\.widgetFamily) private var family
  let entry: UpNextEntry

  var body: some View {
    if #available(iOSApplicationExtension 16.0, *) {
      if family == .accessoryRectangular {
        UpNextRectangularView(entry: entry).widgetBackground(Color.clear, padded: false)
      } else {
        small
      }
    } else {
      small
    }
  }

  private var small: some View {
    UpNextSmallView(entry: entry).widgetBackground(
      ZStack {
        Color(UIColor.systemBackground)
        LinearGradient(
          colors: [brand.opacity(0.16), brand.opacity(0.02)],
          startPoint: .topLeading, endPoint: .bottomTrailing)
      },
      padded: true)
  }
}

// MARK: - Widget

/// Purpose: Pick widget-gallery text for the system language.
/// Inputs: The text in English, Simplified Chinese, Traditional Chinese and Japanese.
/// Returns: `String`.
/// Side effects: None.
/// Notes: Gallery text only; widget content strings come from the app's ARB files.
private func galleryText(_ en: String, zhHans: String, zhHant: String, ja: String) -> String {
  let language = Locale.preferredLanguages.first ?? "en"
  if language.hasPrefix("zh-Hant") || language.hasPrefix("zh-TW") || language.hasPrefix("zh-HK") {
    return zhHant
  }
  if language.hasPrefix("zh") { return zhHans }
  if language.hasPrefix("ja") { return ja }
  return en
}

struct UpNextWidget: Widget {
  /// Widget kind; the app reloads it with `reloadAllTimelines`.
  let kind = "MyAnimeUpNextWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: UpNextProvider()) { entry in
      UpNextEntryView(entry: entry)
    }
    .configurationDisplayName(galleryText("Up next", zhHans: "待看", zhHant: "待看", ja: "次に見る"))
    .description(
      galleryText(
        "New episodes and what is left to watch", zhHans: "番剧更新与待看列表",
        zhHant: "番劇更新與待看清單", ja: "新着エピソードと未視聴リスト")
    )
    .supportedFamilies(Self.families)
  }

  /// Purpose: Return the families this iOS version supports.
  /// Inputs: None.
  /// Returns: `[WidgetFamily]`.
  /// Side effects: None.
  /// Notes: The lock-screen strip needs iOS 16.
  static var families: [WidgetFamily] {
    if #available(iOSApplicationExtension 16.0, *) {
      return [.systemSmall, .accessoryRectangular]
    }
    return [.systemSmall]
  }
}

@main
struct UpNextWidgetBundle: WidgetBundle {
  var body: some Widget {
    UpNextWidget()
  }
}
