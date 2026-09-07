import SwiftUI

/// One endpoint, with the JSON it takes and the JSON it returns.
struct EndpointDetailContent: View {
    let endpoint: EndpointInfo

    var body: some View {
        List {
            Section {
                LabeledContent("Method", value: endpoint.method)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Path")
                        .foregroundStyle(.secondary)
                    Text(endpoint.path)
                        .font(.system(.callout, design: .monospaced))
                        .textSelection(.enabled)
                }
                .padding(.vertical, 2)
            } footer: {
                Text(endpoint.summary)
            }

            if let requestBody = endpoint.requestBody {
                Section {
                    BridgeCodeBlock(content: requestBody)
                } header: {
                    Text("Request")
                }
            }

            Section {
                BridgeCodeBlock(content: endpoint.responseBody)
            } header: {
                Text("Response")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(endpoint.path.split(separator: "/").last.map(String.init) ?? "Endpoint")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct EndpointInfo: Identifiable {
    let id = UUID()
    let method: String
    let path: String
    let summary: String
    let requestBody: String?
    let responseBody: String

    var tint: Color { method == "POST" ? .green : .blue }
    var symbolName: String { method == "POST" ? "arrow.up.circle" : "arrow.down.circle" }

    static let all: [EndpointInfo] = [
        EndpointInfo(
            method: "GET",
            path: "/api/homes",
            summary: "Lists every Apple Home this device can see.",
            requestBody: nil,
            responseBody: """
            {
              "homes": [
                {
                  "id": "HOME_UUID",
                  "name": "My Home",
                  "roomCount": 8,
                  "accessoryCount": 42
                }
              ]
            }
            """
        ),
        EndpointInfo(
            method: "GET",
            path: "/api/homes/{homeId}/accessories",
            summary: "Lists the devices in one home, with the room they sit in and the serial number that pairs them with Home Assistant.",
            requestBody: nil,
            responseBody: """
            {
              "accessories": [
                {
                  "id": "ACCESSORY_UUID",
                  "name": "Kitchen Light",
                  "room": "Kitchen",
                  "manufacturer": "Acme",
                  "model": "A19",
                  "serialNumber": "light.kitchen"
                }
              ]
            }
            """
        ),
        EndpointInfo(
            method: "GET",
            path: "/api/homes/{homeId}/accessories/serials",
            summary: "The same list, kept for scripts that already call this path.",
            requestBody: nil,
            responseBody: """
            {
              "accessories": [
                {
                  "id": "ACCESSORY_UUID",
                  "name": "Kitchen Light",
                  "room": "Kitchen",
                  "serialNumber": "light.kitchen",
                  "manufacturer": "Acme",
                  "model": "A19"
                }
              ]
            }
            """
        ),
        EndpointInfo(
            method: "GET",
            path: "/api/accessories/{accessoryId}/serial",
            summary: "Reads one device's serial number, which is its Home Assistant entity ID when it is bridged.",
            requestBody: nil,
            responseBody: """
            {
              "id": "ACCESSORY_UUID",
              "serialNumber": "light.kitchen"
            }
            """
        ),
        EndpointInfo(
            method: "POST",
            path: "/api/accessories/{accessoryId}/move",
            summary: "Moves one device into another Apple Home room.",
            requestBody: """
            {
              "roomId": "ROOM_UUID"
            }
            """,
            responseBody: """
            {
              "success": true
            }
            """
        ),
        EndpointInfo(
            method: "POST",
            path: "/api/accessories/{accessoryId}/rename",
            summary: "Renames one device in Apple Home.",
            requestBody: """
            {
              "name": "New Accessory Name"
            }
            """,
            responseBody: """
            {
              "success": true
            }
            """
        )
    ]
}
