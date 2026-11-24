import 'package:home_widget/home_widget.dart';

/// Publica no widget da tela inicial as medições mais recentes conhecidas.
/// Enquanto o ESP32 não estiver conectado, os valores exibidos são marcados
/// como demonstração/último registro local.
class VitaHomeWidgetService {
  static const androidWidgetName = 'VitaHomeWidgetProvider';
  static const iosWidgetName = 'VitaHomeWidget';
  static const appGroupId = 'group.com.vita.monitoramento';

  static Future<void> initialize() async {
    try { await HomeWidget.setAppGroupId(appGroupId); } catch (_) { /* Widget nativo pode ainda não estar configurado. */ }
  }

  static Future<void> update({
    required String temperature,
    required String heartRate,
    required String spo2,
    required String updatedAt,
    required bool connected,
  }) async {
    try {
    await HomeWidget.saveWidgetData<String>('temperature', temperature);
    await HomeWidget.saveWidgetData<String>('heartRate', heartRate);
    await HomeWidget.saveWidgetData<String>('spo2', spo2);
    await HomeWidget.saveWidgetData<String>('updatedAt', updatedAt);
    await HomeWidget.saveWidgetData<bool>('connected', connected);
    await HomeWidget.saveWidgetData<String>('dataStatus', connected ? 'BLE conectado · aguardando protocolo de medições' : 'Dados demonstrativos · sem dispositivo');
    await HomeWidget.updateWidget(
      androidName: androidWidgetName,
      iOSName: iosWidgetName,
    );
    } catch (_) { /* O app continua utilizável mesmo sem extensão/widget configurado. */ }
  }
}
