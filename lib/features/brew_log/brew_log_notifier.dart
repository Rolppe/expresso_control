// ============================================================================
// brew_log_notifier.dart — receive Pico brew_log + weight prompt (BG OK)
// ============================================================================

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/debug_log.dart';
import '../../core/providers.dart';
import '../../models/brew_log.dart';
import 'brew_log_assembler.dart';
import 'brew_log_store.dart';

class BrewLogUiState {
  final BrewLog? pending;
  final bool showPrompt;
  final String? lastError;
  /// Bumped when UI should open the weight sheet.
  final int openRequestId;

  const BrewLogUiState({
    this.pending,
    this.showPrompt = false,
    this.lastError,
    this.openRequestId = 0,
  });

  BrewLogUiState copyWith({
    BrewLog? pending,
    bool? showPrompt,
    String? lastError,
    int? openRequestId,
    bool clearPending = false,
  }) =>
      BrewLogUiState(
        pending: clearPending ? null : (pending ?? this.pending),
        showPrompt: showPrompt ?? this.showPrompt,
        lastError: lastError,
        openRequestId: openRequestId ?? this.openRequestId,
      );
}

class BrewLogNotifier extends Notifier<BrewLogUiState> {
  static const _notifyChannel = MethodChannel('espressopico/ble_keepalive');

  StreamSubscription<Map<String, dynamic>>? _sub;
  final _store = BrewLogStore();
  final _assembler = BrewLogAssembler();
  int _openReq = 0;
  /// Survives accidental rebuilds so weight sheet is not wiped mid-flow.
  BrewLogUiState _mem = const BrewLogUiState();

  @override
  BrewLogUiState build() {
    ref.keepAlive();
    // Use read (not watch): watching machineLinkProvider rebuilt this
    // notifier and reset state to empty — pending weight sheet vanished mid-flow.
    final repo = ref.read(machineLinkProvider);
    if (_sub == null) {
      _sub = repo.dataStream.listen(_onJson);
      ref.onDispose(() {
        _sub?.cancel();
        _sub = null;
      });
      DLog.ui('BrewLogNotifier listening (keepAlive, single sub)');
      Future.microtask(_restorePending);
    }
    return _mem;
  }

  void _setUi(BrewLogUiState next) {
    _mem = next;
    state = next;
  }

  Future<void> _restorePending() async {
    final log = await _store.loadPending();
    if (log == null) return;
    DLog.ui('brew log restore pending id=${log.id}');
    _openPrompt(log, notify: true);
  }

  void _onJson(Map<String, dynamic> json) {
    if (json['type'] != 'brew_log') return;
    final r = _assembler.add(json);
    if (r.info != null) DLog.data('brew_log ${r.info}');
    if (r.rejectReason != null) {
      DLog.data('brew_log REJECT ${r.rejectReason}');
      // Samples/end without meta (mid-multipack disconnect / dual-app):
      // clear partial assembly and ask Pico to restart from meta.
      final reason = r.rejectReason!;
      if (reason.contains('no_meta') || reason.contains('missing_assembly')) {
        _assembler.clear();
        _requestBrewLogResend();
      }
      return;
    }
    final log = r.completed;
    if (log == null) return;
    unawaited(_finish(log));
  }

  void _requestBrewLogResend() {
    try {
      ref.read(machineLinkProvider).requestPendingBrewLog();
      DLog.ui('brew_log resend after REJECT (no_meta / missing assembly)');
    } catch (e) {
      DLog.ble('brew_log resend request failed: $e');
    }
  }

  Future<void> _finish(BrewLog log) async {
    if (log.samples.isEmpty) {
      DLog.ui('brew_log ignore empty id=${log.id}');
      return;
    }
    await _store.savePending(log);
    try {
      ref.read(machineLinkProvider).sendCommand('brew_log:ack:${log.id}');
    } catch (e) {
      DLog.ble('brew_log ack failed: $e');
    }
    DLog.ui(
      'brew_log READY id=${log.id} samples=${log.samples.length} '
      'dur=${log.durationMs}ms → open sheet + notify',
    );
    await _openPrompt(log, notify: true);
  }

  /// Always open the in-app form; notification is backup (lock screen).
  Future<void> _openPrompt(BrewLog log, {required bool notify}) async {
    _openReq++;
    _setUi(BrewLogUiState(
      pending: log,
      showPrompt: true,
      openRequestId: _openReq,
    ));
    // Tell Android: if device is locked now, re-lock after user submits the form.
    if (Platform.isAndroid) {
      try {
        await _notifyChannel.invokeMethod<void>('markBrewPromptSession');
      } catch (_) {}
    }
    if (notify) await _showWeightNotification(log);
  }

  /// HomeView on resume / notification open — re-request sheet if still pending.
  Future<void> onAppResumed() async {
    if (state.pending == null || !state.showPrompt) return;
    if (Platform.isAndroid) {
      try {
        await _notifyChannel.invokeMethod<void>('markBrewPromptSession');
      } catch (_) {}
    }
    _openReq++;
    _setUi(state.copyWith(openRequestId: _openReq));
    DLog.ui('onAppResumed: re-open sheet openReq=$_openReq');
  }

  Future<void> _showWeightNotification(BrewLog log) async {
    // iOS: AppDelegate posts a local notification (asks permission itself).
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      if (Platform.isAndroid) await Permission.notification.request();
      final secs = (log.durationMs / 1000).toStringAsFixed(0);
      await _notifyChannel.invokeMethod<void>('showBrewWeightPrompt', {
        'title': 'Uutto tallennettu',
        'body':
            'Kesto ${secs}s · ${log.samples.length} näytettä. '
            'Syötä toteutunut paino.',
      });
      DLog.ui('brew weight notification shown');
    } catch (e) {
      DLog.ui('brew weight notification failed: $e');
    }
  }

  Future<void> _cancelWeightNotification() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      await _notifyChannel.invokeMethod<void>('cancelBrewWeightPrompt');
    } catch (_) {}
  }

  /// After form: lock screen if this session came from lock / was locked.
  Future<void> _returnToLockIfNeeded() async {
    if (!Platform.isAndroid) return;
    await Future<void>.delayed(const Duration(milliseconds: 300));
    try {
      final did = await _notifyChannel.invokeMethod<bool>('returnToLockAfterBrew');
      DLog.ui('returnToLockAfterBrew → $did');
    } catch (e) {
      DLog.ui('returnToLockAfterBrew failed: $e');
    }
  }

  Future<void> saveWithActualWeight({
    required double actualG,
    int? satisfactionLevel,
    String? satisfactionEmoji,
  }) async {
    final log = state.pending;
    if (log == null) return;
    if (log.samples.isEmpty) {
      DLog.ui('brew log refuse save: empty samples');
      await _store.clearPending();
      await _cancelWeightNotification();
      _setUi(const BrewLogUiState(showPrompt: false));
      await _returnToLockIfNeeded();
      return;
    }
    DLog.ui(
      'USER_INPUT save weight actual=${actualG}g sat=${satisfactionLevel ?? 'none'} '
      'id=${log.id} samples=${log.samples.length}',
    );
    await _store.append(
      log: log,
      actualWeightG: actualG,
      satisfactionLevel: satisfactionLevel,
      satisfactionEmoji: satisfactionEmoji,
    );
    await _store.clearPending();
    await _cancelWeightNotification();
    _setUi(const BrewLogUiState(showPrompt: false));
    DLog.ui('USER_INPUT saved OK id=${log.id}');
    await _returnToLockIfNeeded();
  }

  Future<void> dismiss() async {
    DLog.ui('USER_INPUT dismiss pending id=${state.pending?.id}');
    await _store.clearPending();
    await _cancelWeightNotification();
    _setUi(const BrewLogUiState(showPrompt: false));
    await _returnToLockIfNeeded();
  }
}

final brewLogProvider =
    NotifierProvider<BrewLogNotifier, BrewLogUiState>(BrewLogNotifier.new);
