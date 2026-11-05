import SwiftUI

/// A planet in the solar system.
struct Planet: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var distance: Double   // AU
    var moons: Int

    var isGasGiant: Bool { ["Jupiter", "Saturn"].contains(name) }
}

struct PlanetList: View {
    let planets: [Planet]

    var body: some View {
        List(planets) { planet in
            HStack {
                Text(planet.name).font(.headline)
                Spacer()
                Text("\(planet.moons) moons")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Planets")
    }
}
