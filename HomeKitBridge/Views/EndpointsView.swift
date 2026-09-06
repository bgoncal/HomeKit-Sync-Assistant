import SwiftUI

struct EndpointsView: View {
    private let endpoints: [EndpointInfo] = [
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
            summary: "Lists the devices in one home, with the room they sit in and the serial number used to pair them with Home Assistant.",
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
            summary: "Same list, kept for older scripts that call the /serials path.",
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

    var body: some View {
        BridgePage(
            title: "Local API",
            subtitle: "Let your own scripts read and change Apple Home over your local network."
        ) {
            BridgeCard {
                BridgeStatusHeader(
                    title: "Reads and writes Apple Home only",
                    message: "These endpoints never touch Home Assistant. They are unauthenticated, so only use them from tools you trust on your own network.",
                    systemImage: "point.3.connected.trianglepath.dotted",
                    tint: .blue
                )

                Text("Send requests to this device on the port shown in Settings, for example http://<this-device>:8400/api/homes")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            LazyVStack(spacing: 12) {
                ForEach(endpoints) { endpoint in
                    endpointCard(endpoint)
                }
            }
        }
    }

    private func endpointCard(_ endpoint: EndpointInfo) -> some View {
        BridgeCard {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(endpoint.method)
                    .font(.caption.bold())
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(methodColor(endpoint.method).opacity(0.18))
                    .foregroundStyle(methodColor(endpoint.method))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                Text(endpoint.path)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }

            Text(endpoint.summary)
                .font(.callout)
                .foregroundStyle(.secondary)

            DisclosureGroup("Examples") {
                VStack(alignment: .leading, spacing: 12) {
                    if let requestBody = endpoint.requestBody {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Request JSON")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            BridgeCodeBlock(content: requestBody)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Response JSON")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        BridgeCodeBlock(content: endpoint.responseBody)
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    private func methodColor(_ method: String) -> Color {
        switch method {
        case "GET": return .blue
        case "POST": return .green
        default: return .secondary
        }
    }
}

private struct EndpointInfo: Identifiable {
    let id = UUID()
    let method: String
    let path: String
    let summary: String
    let requestBody: String?
    let responseBody: String
}
