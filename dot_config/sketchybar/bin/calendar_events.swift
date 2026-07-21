import EventKit
import Foundation

let store = EKEventStore()
let sema = DispatchSemaphore(value: 0)
var granted = false

let handler: (Bool, Error?) -> Void = { ok, _ in
    granted = ok
    sema.signal()
}

if #available(macOS 14.0, *) {
    store.requestFullAccessToEvents(completion: handler)
} else {
    store.requestAccess(to: .event, completion: handler)
}
sema.wait()

guard granted else { exit(0) }

let now = Date()
let cal = Calendar.current
let start = cal.startOfDay(for: now)
guard let end = cal.date(byAdding: .day, value: 7, to: start) else { exit(0) }

let pred = store.predicateForEvents(withStart: start, end: end, calendars: nil)
var events = store.events(matching: pred)
    .filter { !$0.isAllDay && $0.endDate > now }
    .sorted { $0.startDate < $1.startDate }

if CommandLine.arguments.contains("--next") {
    events = events.first.map { [$0] } ?? []
} else {
    events = Array(events.prefix(10))
}

let timeFmt = DateFormatter()
timeFmt.locale = Locale(identifier: "en_US_POSIX")
timeFmt.dateFormat = "HH:mm"

let dayTimeFmt = DateFormatter()
dayTimeFmt.locale = Locale(identifier: "en_US_POSIX")
dayTimeFmt.dateFormat = "EEE HH:mm"

for ev in events {
    let title = ev.title ?? "(untitled)"
    if cal.isDateInToday(ev.startDate) {
        print("\(timeFmt.string(from: ev.startDate))  \(title)")
    } else {
        print("\(dayTimeFmt.string(from: ev.startDate))  \(title)")
    }
}
