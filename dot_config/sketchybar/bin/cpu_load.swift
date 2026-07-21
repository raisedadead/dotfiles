import Darwin
import Foundation

func cpuTicks() -> (busy: UInt64, total: UInt64)? {
    var size = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
    var info = host_cpu_load_info_data_t()
    let kr = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
            host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &size)
        }
    }
    guard kr == KERN_SUCCESS else { return nil }
    let user = UInt64(info.cpu_ticks.0)
    let system = UInt64(info.cpu_ticks.1)
    let idle = UInt64(info.cpu_ticks.2)
    let nice = UInt64(info.cpu_ticks.3)
    return (user + system + nice, user + system + nice + idle)
}

func memTotal() -> UInt64 {
    var v: UInt64 = 0
    var sz = MemoryLayout<UInt64>.size
    sysctlbyname("hw.memsize", &v, &sz, nil, 0)
    return v
}

func memUsedPct(total: UInt64) -> Int? {
    var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
    var vm = vm_statistics64_data_t()
    let kr = withUnsafeMutablePointer(to: &vm) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
            host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &size)
        }
    }
    guard kr == KERN_SUCCESS, total > 0 else { return nil }
    let page = UInt64(vm_page_size)
    let used = (UInt64(vm.active_count) + UInt64(vm.wire_count) + UInt64(vm.compressor_page_count)) * page
    return Int((Double(used) / Double(total) * 100).rounded())
}

func netBytes() -> (rx: UInt64, tx: UInt64) {
    var addrs: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&addrs) == 0 else { return (0, 0) }
    defer { freeifaddrs(addrs) }
    var rx: UInt64 = 0
    var tx: UInt64 = 0
    var p = addrs
    while let cur = p {
        let ifa = cur.pointee
        if ifa.ifa_addr?.pointee.sa_family == UInt8(AF_LINK),
            let data = ifa.ifa_data?.assumingMemoryBound(to: if_data.self),
            String(cString: ifa.ifa_name).hasPrefix("en") {
            rx &+= UInt64(data.pointee.ifi_ibytes)
            tx &+= UInt64(data.pointee.ifi_obytes)
        }
        p = ifa.ifa_next
    }
    return (rx, tx)
}

let interval = CommandLine.arguments.count > 1 ? (Double(CommandLine.arguments[1]) ?? 5) : 5
let total = memTotal()
var prev = cpuTicks()
var prevNet = netBytes()
while true {
    Thread.sleep(forTimeInterval: interval)
    guard let cur = cpuTicks() else { continue }
    guard let p = prev else { prev = cpuTicks(); continue }
    prev = cur
    let db = cur.busy &- p.busy
    let dt = cur.total &- p.total
    guard dt > 0 else { continue }
    let cpu = Int((Double(db) / Double(dt) * 100).rounded())
    let mem = memUsedPct(total: total) ?? 0
    let net = netBytes()
    let rxRate = net.rx >= prevNet.rx ? UInt64(Double(net.rx - prevNet.rx) / interval) : 0
    let txRate = net.tx >= prevNet.tx ? UInt64(Double(net.tx - prevNet.tx) / interval) : 0
    prevNet = net
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/sketchybar")
    task.arguments = ["--trigger", "system_stats", "CPU=\(cpu)", "MEM=\(mem)", "NET_RX=\(rxRate)", "NET_TX=\(txRate)"]
    try? task.run()
    task.waitUntilExit()
}
