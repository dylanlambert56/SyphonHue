import Foundation
import CoreMIDI

struct MIDIDestination: Identifiable, Hashable {
    var id: MIDIUniqueID
    var name: String
    var endpointRef: MIDIEndpointRef
}

final class MIDIOut {
    private var client: MIDIClientRef = 0
    private var outputPort: MIDIPortRef = 0
    private(set) var destinations: [MIDIDestination] = []
    private(set) var selected: MIDIDestination?

    init() {
        MIDIClientCreateWithBlock("SyphonHue" as CFString, &client) { _ in }
        MIDIOutputPortCreate(client, "SyphonHue Out" as CFString, &outputPort)
        refreshDestinations()
    }

    deinit {
        if outputPort != 0 { MIDIPortDispose(outputPort) }
        if client != 0 { MIDIClientDispose(client) }
    }

    func refreshDestinations() {
        let count = MIDIGetNumberOfDestinations()
        var result: [MIDIDestination] = []
        for i in 0..<count {
            let endpoint = MIDIGetDestination(i)
            var name: Unmanaged<CFString>?
            MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &name)
            var uniqueID: MIDIUniqueID = 0
            MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyUniqueID, &uniqueID)
            let n = (name?.takeRetainedValue() as String?) ?? "Unknown"
            result.append(MIDIDestination(id: uniqueID, name: n, endpointRef: endpoint))
        }
        destinations = result
        if let sel = selected, !destinations.contains(where: { $0.id == sel.id }) {
            selected = nil
        }
    }

    func select(_ dest: MIDIDestination?) {
        selected = dest
    }

    @discardableResult
    func selectByName(_ name: String) -> Bool {
        if let match = destinations.first(where: { $0.name == name }) {
            selected = match
            return true
        }
        return false
    }

    static func ccBytes(channel: Int, cc: Int, value: Int) -> [UInt8] {
        let ch = max(1, min(16, channel)) - 1
        let status: UInt8 = 0xB0 | UInt8(ch)
        let controller = UInt8(max(0, min(127, cc)))
        let v = UInt8(max(0, min(127, value)))
        return [status, controller, v]
    }

    func sendCC(channel: Int, cc: Int, value: Int) {
        guard let dest = selected else { return }
        let bytes = Self.ccBytes(channel: channel, cc: cc, value: value)
        var packetList = MIDIPacketList()
        let packet = MIDIPacketListInit(&packetList)
        _ = MIDIPacketListAdd(&packetList, MemoryLayout<MIDIPacketList>.size, packet, 0, bytes.count, bytes)
        MIDISend(outputPort, dest.endpointRef, &packetList)
    }
}
