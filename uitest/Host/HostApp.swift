// Tyhjä isäntä: XCUITest vaatii kohdeäpin, mutta ohjain ajaa expresso-äppiä bundle-tunnisteella.
import SwiftUI

@main
struct OhjainHost: App {
    var body: some Scene { WindowGroup { Text("expresso-ohjain") } }
}
