import SwiftUI

struct EndpointsView: View {
    private let endpoints: [EndpointInfo] = [
        EndpointInfo(
            method: "GET",
            path: "/api/homes",
            summary: "Lists every Apple Home available to the bridge.",
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
            summary: "Lists accessories in a Home, including room, manufacturer, model, and serial number.",
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
            summary: "Lists accessories in a Home with serial numbers for Home Assistant entity matching.",
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
            summary: "Reads the serial number from one HomeKit accessory.",
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
            summary: "Moves one HomeKit accessory to the supplied HomeKit room.",
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
            summary: "Renames one HomeKit accessory.",
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
            subtitle: "Reference for automations and local integrations. Request and response examples are tucked away until needed."
        ) {
            BridgeCard {
                BridgeStatusHeader(
                    title: "Developer Reference",
                    message: "Use these endpoints from trusted tools on your local network.",
                    systemImage: "point.3.connected.trianglepath.dotted",
                    tint: .blue
                )
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
