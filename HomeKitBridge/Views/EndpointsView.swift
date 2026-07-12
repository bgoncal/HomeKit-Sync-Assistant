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
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Endpoints")
                    .font(.largeTitle.bold())

                ForEach(endpoints) { endpoint in
                    endpointCard(endpoint)
                }
            }
            .padding(20)
        }
    }

    private func endpointCard(_ endpoint: EndpointInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(endpoint.method)
                    .font(.caption.bold())
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(methodColor(endpoint.method).opacity(0.18))
                    .foregroundStyle(methodColor(endpoint.method))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                Text(endpoint.path)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            }

            Text(endpoint.summary)
                .foregroundStyle(.secondary)

            if let requestBody = endpoint.requestBody {
                codeBlock(title: "Expected JSON", content: requestBody)
            }

            codeBlock(title: "Response JSON", content: endpoint.responseBody)
        }
        .padding()
        .background(.quaternary.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func codeBlock(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            Text(content)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(.black.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 6))
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
