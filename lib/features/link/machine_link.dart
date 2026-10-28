// ============================================================================
// machine_link.dart — transport between the app and the Pico (BLE or Wi-Fi)
// ============================================================================
// EXPRESSO-WIFI-APPI vaihe 2: the surface the UI already used on BLERepository,
// lifted into an interface so BLERepository, WifiRepository and LinkSelector
// can stand in for each other. Data on [dataStream] is the Pico's JSON objects
// (live, scale, settings A+B, pcal/cal state, brew_log frames) whatever the
// transport.

abstract class MachineLink {
  /// Emits when the link goes up or down (broadcast, no replay).
  Stream<bool> get isConnectedStream;

  bool get isConnected;

  /// One decoded JSON object per event.
  Stream<Map<String, dynamic>> get dataStream;

  Future<void> sendCommand(String command);

  /// Ask the Pico to (re)send the pending brew_log multipack.
  void requestPendingBrewLog();

  Future<void> onAppResumed();

  void onAppPaused();

  /// (Re)start looking for the Pico.
  Future<void> startScan({bool force = false});

  Future<void> disconnect();

  String deviceSummary();
}

/// The Wi-Fi side of the pair: a [MachineLink] with a start switch and the
/// numbers Settings shows.
abstract class WifiLink implements MachineLink {
  /// Load the key and begin (idempotent). Without a key nothing is sent.
  Future<void> start();

  bool get hasKey;

  /// The Pico's boot id from its last hello, null before one.
  String? get bootId;

  DateTime? get lastPacketAt;
}
