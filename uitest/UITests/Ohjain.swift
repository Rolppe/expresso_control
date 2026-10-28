// Ohjain: ajaa expresso-äppiä (io.github.rolppe.silviaPicoUi) simulaattorissa askellistan mukaan.
// Askeleet tiedostosta /tmp/expresso-ohjain/askeleet.txt, yksi per rivi:
//   tap:<label>   napauttaa ensimmäistä elementtiä, jonka label tai tunniste sisältää tekstin
//   tapeq:<label> napauttaa elementtiä, jonka label on täsmälleen teksti (esim. Save vs. otsikko)
//   longpress:<label> pitkä painallus (1 s) samalla haulla kuin tap
//   tapif:<label> napauttaa, jos elementti on näkyvissä (esim. demon uuttolomakkeen Ohita)
//   tapxy:<x>,<y> napauttaa normalisoitua kohtaa (0–1); Flutterin kenttä kortissa: XCUITestin
//                 TextField kattaa koko kortin, joten keskipisteen napautus ei fokusoi kenttää
//   type:<teksti> kirjoittaa fokusoituun kenttään
//   clear         tyhjentää fokusoidun kentän
//   allow         hyväksyy järjestelmän lupaikkunan (Allow), jos sellainen on
//   wait:<s>      odottaa sekunteja
//   shot:<nimi>   kuvakaappaus /tmp/expresso-ohjain/<nimi>.png
//   dump:<nimi>   elementtipuu /tmp/expresso-ohjain/<nimi>.txt
//   waitfor:<teksti>[|s] odottaa elementtiä, jonka label sisältää tekstin (oletus 60 s)
//   home          kotinäppäin (äppi taustalle)
//   orient:landscape|portrait  kääntää laitteen
//   swipeup / swipedown  vierittää; backswipe = iOS:n reunapyyhkäisy takaisin
//   launch        käynnistää äpin uudelleen; activate tuo sen etualalle
import XCTest

final class Ohjain: XCTestCase {
    let hakemisto = URL(fileURLWithPath: "/tmp/expresso-ohjain")

    func testAskeleet() throws {
        let app = XCUIApplication(bundleIdentifier: "io.github.rolppe.silviaPicoUi")
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let rivit = try String(contentsOf: hakemisto.appendingPathComponent("askeleet.txt"), encoding: .utf8)
            .split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty && !$0.hasPrefix("#") }
        app.activate()
        for rivi in rivit {
            let osat = rivi.split(separator: ":", maxSplits: 1).map(String.init)
            let komento = osat[0], arvo = osat.count > 1 ? osat[1] : ""
            print("OHJAIN: \(rivi)")
            switch komento {
            case "tap":
                let p = NSPredicate(format: "label CONTAINS %@ OR identifier CONTAINS %@", arvo, arvo)
                let e = app.descendants(matching: .any).matching(p).firstMatch
                // Demo avaa uuttolomakkeen ~3 min välein: suljetaan se, jos se peittää kohteen.
                let ohita = app.buttons["Ohita"]
                if !e.waitForExistence(timeout: 2) && arvo != "Ohita" && ohita.exists {
                    print("OHJAIN: uuttolomake auki → Ohita")
                    ohita.tap()
                }
                guard e.waitForExistence(timeout: 5) else {
                    // Tila talteen vianetsintää varten ennen keskeytystä.
                    try XCUIScreen.main.screenshot().pngRepresentation
                        .write(to: hakemisto.appendingPathComponent("virhe.png"))
                    try app.debugDescription.write(to: hakemisto.appendingPathComponent("virhe.txt"),
                                                   atomically: true, encoding: .utf8)
                    XCTFail("ei löydy: \(arvo)")
                    return
                }
                e.tap()
            case "tapeq":
                let e = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", arvo)).firstMatch
                guard e.waitForExistence(timeout: 5) else { XCTFail("ei löydy: \(arvo)"); return }
                e.tap()
            case "longpress":
                let p = NSPredicate(format: "label CONTAINS %@ OR identifier CONTAINS %@", arvo, arvo)
                let e = app.descendants(matching: .any).matching(p).firstMatch
                guard e.waitForExistence(timeout: 5) else { XCTFail("ei löydy: \(arvo)"); return }
                e.press(forDuration: 1.0)
            case "tapif":
                let p = NSPredicate(format: "label CONTAINS %@", arvo)
                let e = app.descendants(matching: .any).matching(p).firstMatch
                if e.waitForExistence(timeout: 2) { e.tap() } else { print("OHJAIN: ei näkyvissä: \(arvo)") }
            case "tapxy":
                let xy = arvo.split(separator: ",").compactMap { Double($0) }
                app.coordinate(withNormalizedOffset: CGVector(dx: xy[0], dy: xy[1])).tap()
            case "type":
                app.typeText(arvo)
            case "clear":
                app.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 20))
            case "allow":
                let b = springboard.buttons["Allow"]
                if b.waitForExistence(timeout: 3) { b.tap() } else { print("OHJAIN: ei lupaikkunaa") }
            case "wait":
                Thread.sleep(forTimeInterval: Double(arvo) ?? 1)
            case "shot":
                try XCUIScreen.main.screenshot().pngRepresentation
                    .write(to: hakemisto.appendingPathComponent("\(arvo).png"))
            case "dump":
                try app.debugDescription.write(to: hakemisto.appendingPathComponent("\(arvo).txt"),
                                               atomically: true, encoding: .utf8)
            case "waitfor":
                let parts = arvo.split(separator: "|").map(String.init)
                let p = NSPredicate(format: "label CONTAINS %@", parts[0])
                let ok = app.descendants(matching: .any).matching(p).firstMatch
                    .waitForExistence(timeout: Double(parts.count > 1 ? parts[1] : "60") ?? 60)
                print("OHJAIN: waitfor \(parts[0]) → \(ok)")
            case "home":
                XCUIDevice.shared.press(.home)
            case "orient":
                XCUIDevice.shared.orientation = arvo == "landscape" ? .landscapeLeft : .portrait
            case "backswipe":
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
                    .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)))
            case "swipeup":
                app.swipeUp()
            case "swipedown":
                app.swipeDown()
            case "launch":
                app.launch()
            case "activate":
                app.activate()
            default:
                XCTFail("tuntematon askel: \(rivi)")
            }
        }
    }
}
