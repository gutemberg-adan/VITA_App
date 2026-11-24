import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// Gerencia descoberta e conexão BLE. A conexão é opcional para usar o app.
/// O protocolo GATT do firmware V.I.T.A. deverá ser configurado quando os UUIDs
/// do serviço e das características do ESP32 forem definidos.
class VitaBluetoothService extends ChangeNotifier {
  BluetoothAdapterState adapterState = BluetoothAdapterState.unknown;
  final List<ScanResult> devices = [];
  List<BluetoothService> discoveredServices = const [];
  BluetoothDevice? connectedDevice;
  bool scanning = false;
  bool connecting = false;
  String? errorMessage;

  StreamSubscription<BluetoothAdapterState>? _adapterSub;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<bool>? _scanningSub;
  StreamSubscription<BluetoothConnectionState>? _connectionSub;

  VitaBluetoothService() {
    _adapterSub = FlutterBluePlus.adapterState.listen((state) {
      adapterState = state;
      notifyListeners();
    });
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      devices
        ..clear()
        ..addAll(results);
      notifyListeners();
    });
    _scanningSub = FlutterBluePlus.isScanning.listen((value) {
      scanning = value;
      notifyListeners();
    });
  }

  bool get isConnected => connectedDevice != null;
  bool get bluetoothOn => adapterState == BluetoothAdapterState.on;
  String get adapterStateLabel => adapterState == BluetoothAdapterState.on ? 'Ativado' : adapterState == BluetoothAdapterState.off ? 'Desativado' : 'Indisponível';

  Future<bool> _requestPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final permissions = <Permission>[Permission.bluetoothScan, Permission.bluetoothConnect];
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt <= 30) permissions.add(Permission.locationWhenInUse);
      final statuses = await permissions.request();
      return statuses.values.every((status) => status.isGranted || status.isLimited);
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final status = await Permission.bluetooth.request();
      return status.isGranted || status.isLimited;
    }
    return false;
  }

  Future<void> startScan() async {
    errorMessage = null;
    if (!await _requestPermissions()) {
      errorMessage = 'Permissão de Bluetooth/localização não concedida. Você pode continuar usando o aplicativo sem conectar o dispositivo.';
      notifyListeners();
      return;
    }
    try {
      final supported = await FlutterBluePlus.isSupported;
      if (!supported) {
        errorMessage = 'Este aparelho não oferece suporte a Bluetooth Low Energy.';
        notifyListeners();
        return;
      }
      if (adapterState != BluetoothAdapterState.on) {
        errorMessage = 'Ative o Bluetooth do telefone para procurar o V.I.T.A.';
        notifyListeners();
        return;
      }
      devices.clear();
      scanning = true;
      notifyListeners();
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 12),
        androidUsesFineLocation: true,
      );
    } catch (e) {
      scanning = false;
      errorMessage = 'Não foi possível iniciar a busca Bluetooth: $e';
      notifyListeners();
    }
  }

  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    scanning = false;
    notifyListeners();
  }

  Future<void> connect(BluetoothDevice device) async {
    errorMessage = null;
    connecting = true;
    notifyListeners();
    try {
      await stopScan();
      await device.connect(timeout: const Duration(seconds: 15), autoConnect: false);
      connectedDevice = device;
      // Descobre a árvore GATT. A leitura/assinatura das características será
      // ativada quando os UUIDs e o formato definidos no firmware forem conhecidos.
      discoveredServices = await device.discoverServices();
      await _connectionSub?.cancel();
      _connectionSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected && connectedDevice?.remoteId == device.remoteId) {
          connectedDevice = null;
          notifyListeners();
        }
      });
    } catch (e) {
      connectedDevice = null;
      discoveredServices = const [];
      try { await device.disconnect(); } catch (_) {}
      errorMessage = 'Falha ao conectar. Verifique se o ESP32 está ligado e próximo. ($e)';
    } finally {
      connecting = false;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    final device = connectedDevice;
    if (device == null) return;
    try {
      await device.disconnect();
    } finally {
      connectedDevice = null;
      discoveredServices = const [];
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _adapterSub?.cancel();
    _scanSub?.cancel();
    _scanningSub?.cancel();
    _connectionSub?.cancel();
    super.dispose();
  }
}
