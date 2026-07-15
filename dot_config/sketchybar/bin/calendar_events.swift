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
guard let end = cal.date(byAdding: .day, value: 1, to: start) else { exit(0) }

let pred = store.predicateForEvents(withStart: start, end: end, calendars: nil)
var events = store.events(matching: pred)
    .filter { !$0.isAllDay }
    .sorted { $0.startDate < $1.startDate }

if CommandLine.arguments.contains("--next") {
    events = events.first(where: { $0.endDate > now }).map { [$0] } ?? []
}

let fmt = DateFormatter()
fmt.locale = Locale(identifier: "en_US_POSIX")
fmt.dateFormat = "HH:mm"

for ev in events {
    print("\(fmt.string(from: ev.startDate))  \(ev.title ?? "(untitled)")")
}
