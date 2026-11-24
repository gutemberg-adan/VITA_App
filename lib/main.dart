import 'dart:io';
import 'dart:typed_data';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/bluetooth_service.dart';
import 'services/vita_home_widget_service.dart';

const blue = Color(0xFF1979EE);
const ink = Color(0xFF18283D);
const muted = Color(0xFF77849A);
const bg = Color(0xFFF4F7FB);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  Intl.defaultLocale = 'pt_BR';
  runApp(const VitaApp());
}

class VitaApp extends StatefulWidget {
  const VitaApp({super.key});
  @override
  State<VitaApp> createState() => _VitaAppState();
}

class _VitaAppState extends State<VitaApp> {
  ThemeMode themeMode = ThemeMode.light;
  bool logged = false;
  String userName = 'João da Silva';
  int selected = 0;
  final VitaBluetoothService bluetooth = VitaBluetoothService();
  final List<Reading> readings = List.generate(6, (i) => Reading(
    date: DateTime.now().subtract(Duration(days: i)),
    temperature: [36.8, 36.6, 36.7, 36.5, 37.2, 36.4][i],
    heart: [72, 78, 70, 69, 75, 68][i],
    spo2: [98, 97, 98, 99, 97, 99][i],
  ));
  @override
  void initState() { super.initState(); bluetooth.addListener(_updateHomeWidget); _initializeWidget(); _load(); }
  Future<void> _initializeWidget() async { await VitaHomeWidgetService.initialize(); if (mounted) _updateHomeWidget(); }
  void _updateHomeWidget() {
    if (readings.isEmpty) return;
    final r = readings.first;
    VitaHomeWidgetService.update(temperature: '${r.temperature.toStringAsFixed(1)} °C', heartRate: '${r.heart} bpm', spo2: '${r.spo2}%', updatedAt: DateFormat('dd/MM HH:mm').format(r.date), connected: bluetooth.isConnected);
  }
  @override
  void dispose() { bluetooth.removeListener(_updateHomeWidget); bluetooth.dispose(); super.dispose(); }
  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() { logged = p.getBool('auth') ?? false; userName = p.getString('name') ?? userName; themeMode = (p.getString('theme') == 'dark') ? ThemeMode.dark : ThemeMode.light; });
  }
  Future<void> login(String name) async { final p = await SharedPreferences.getInstance(); await p.setBool('auth', true); await p.setString('name', name); setState(() { logged = true; userName = name; selected = 0; }); }
  Future<void> logout() async { final p = await SharedPreferences.getInstance(); await p.setBool('auth', false); setState(() { logged = false; selected = 0; }); }
  Future<void> setTheme(bool dark) async { final p = await SharedPreferences.getInstance(); await p.setString('theme', dark ? 'dark' : 'light'); setState(() => themeMode = dark ? ThemeMode.dark : ThemeMode.light); }
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'V.I.T.A.', debugShowCheckedModeBanner: false, themeMode: themeMode,
    theme: _theme(Brightness.light), darkTheme: _theme(Brightness.dark),
    home: logged ? VitaShell(userName: userName, selected: selected, onSelect: (v) => setState(() => selected = v), readings: readings, bluetooth: bluetooth, onLogout: logout, dark: themeMode == ThemeMode.dark, onTheme: setTheme, onName: (v) => setState(() => userName = v)) : LoginScreen(onLogin: login),
  );
}

ThemeData _theme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(seedColor: blue, brightness: brightness);
  return ThemeData(useMaterial3: true, colorScheme: scheme, scaffoldBackgroundColor: dark ? const Color(0xFF101827) : bg,
    cardTheme: CardTheme(color: dark ? const Color(0xFF1B293B) : Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: dark ? Colors.white10 : const Color(0xFFE6ECF3)))),
    appBarTheme: AppBarTheme(backgroundColor: dark ? const Color(0xFF101827) : bg, foregroundColor: dark ? Colors.white : ink, elevation: 0),
    inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: dark ? const Color(0xFF253449) : const Color(0xFFF7F9FC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
  );
}

class Reading {
  Reading({required this.date, required this.temperature, required this.heart, required this.spo2});
  final DateTime date; final double temperature; final int heart; final int spo2;
  String get status => temperature >= 37.2 || heart > 100 || spo2 < 95 ? 'Atenção' : 'Normal';
}

const navItems = [
  (Icons.dashboard_rounded, 'Painel de Controle'), (Icons.history_rounded, 'Meu Histórico'),
  (Icons.show_chart_rounded, 'Gráficos'), (Icons.description_outlined, 'Relatórios'),
  (Icons.notifications_none_rounded, 'Alertas'), (Icons.watch_outlined, 'Dispositivo'),
  (Icons.settings_outlined, 'Configurações'), (Icons.help_outline_rounded, 'Ajuda e Suporte'),
];

class VitaShell extends StatelessWidget {
  const VitaShell({super.key, required this.userName, required this.selected, required this.onSelect, required this.readings, required this.bluetooth, required this.onLogout, required this.dark, required this.onTheme, required this.onName});
  final String userName; final int selected; final ValueChanged<int> onSelect; final List<Reading> readings; final VitaBluetoothService bluetooth; final VoidCallback onLogout; final bool dark; final ValueChanged<bool> onTheme; final ValueChanged<String> onName;
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 900;
    final pages = [
      AnimatedBuilder(animation: bluetooth, builder: (context, _) => DashboardPage(userName: userName, readings: readings, bluetooth: bluetooth, go: onSelect)),
      HistoryPage(readings: readings), ChartsPage(readings: readings), ReportsPage(readings: readings),
      const AlertsPage(), DevicePage(bluetooth: bluetooth), SettingsPage(dark: dark, onTheme: onTheme),
      HelpPage(),
    ];
    return Scaffold(
      appBar: AppBar(leading: wide ? null : Builder(builder: (c) => IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(c).openDrawer())), title: const VitaBrand(), actions: [IconButton(tooltip: 'Notificações', onPressed: () => onSelect(4), icon: const Icon(Icons.notifications_none)), PopupMenuButton<String>(onSelected: (v) { if (v == 'account') _account(context); if (v == 'logout') onLogout(); }, itemBuilder: (_) => [PopupMenuItem(value: 'account', child: Text('Minha conta · $userName')), const PopupMenuItem(value: 'logout', child: Text('Sair'))], child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: CircleAvatar(backgroundColor: blue.withOpacity(.12), child: Text(userName.isNotEmpty ? userName[0].toUpperCase() : 'U', style: const TextStyle(color: blue, fontWeight: FontWeight.bold))))), const SizedBox(width: 8)],),
      drawer: wide ? null : Drawer(child: _nav(context, onSelect, selected, onLogout)),
      body: Row(children: [if (wide) SizedBox(width: 260, child: _nav(context, onSelect, selected, onLogout)), Expanded(child: SafeArea(top: false, child: AnimatedSwitcher(duration: const Duration(milliseconds: 180), child: SingleChildScrollView(key: ValueKey(selected), padding: EdgeInsets.all(width < 600 ? 16 : 28), child: pages[selected])))]),
      bottomNavigationBar: wide ? null : NavigationBar(selectedIndex: selected > 4 ? 4 : selected, onDestinationSelected: onSelect, destinations: const [NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Início'), NavigationDestination(icon: Icon(Icons.history), label: 'Histórico'), NavigationDestination(icon: Icon(Icons.show_chart), label: 'Gráficos'), NavigationDestination(icon: Icon(Icons.description_outlined), label: 'Relatórios'), NavigationDestination(icon: Icon(Icons.menu), label: 'Mais')]),
    );
  }
  Widget _nav(BuildContext context, ValueChanged<int> onSelect, int current, VoidCallback logout) => Container(color: Theme.of(context).cardTheme.color, padding: const EdgeInsets.fromLTRB(14, 18, 14, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [const VitaBrand(), const SizedBox(height: 26), ...List.generate(navItems.length, (i) => Padding(padding: const EdgeInsets.only(bottom: 5), child: ListTile(selected: current == i, selectedTileColor: blue.withOpacity(.10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), leading: Icon(navItems[i].$1, color: current == i ? blue : muted), title: Text(navItems[i].$2, style: TextStyle(fontSize: 13, fontWeight: current == i ? FontWeight.w700 : FontWeight.w500)), onTap: () => onSelect(i)))), const Spacer(), Card(color: const Color(0xFFFFF0F0), child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [const Icon(Icons.sos_rounded, color: Color(0xFFEF3E45), size: 32), const Text('Emergência', style: TextStyle(color: ink, fontWeight: FontWeight.bold)), const Text('Acione o alerta geral', style: TextStyle(color: muted, fontSize: 11)), const SizedBox(height: 8), FilledButton(style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF3E45)), onPressed: () => _sos(context), child: const Text('Acionar SOS'))]))), const SizedBox(height: 8), TextButton.icon(onPressed: logout, icon: const Icon(Icons.logout), label: const Text('Sair'))]));
  void _account(BuildContext context) => showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Minha conta'), content: Text('Usuário: $userName\nAs informações de cadastro são demonstrativas nesta versão.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar'))]));
}

class VitaBrand extends StatelessWidget { const VitaBrand({super.key}); @override Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.monitor_heart_rounded, color: blue, size: 30), const SizedBox(width: 9), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('V.I.T.A.', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 19, color: Theme.of(context).colorScheme.onSurface)), const Text('Monitoramento de Sinais Vitais', style: TextStyle(fontSize: 9, color: muted))])]); }

void _sos(BuildContext context) => showDialog(context: context, builder: (ctx) => AlertDialog(icon: const Icon(Icons.sos_rounded, color: Color(0xFFEF3E45), size: 42), title: const Text('Acionar emergência?'), content: const Text('O V.I.T.A. está em modo demonstrativo. Nenhum alerta real será enviado nesta versão.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')), FilledButton(style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF3E45)), onPressed: () { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SOS demonstrativo confirmado. Nenhum contato foi acionado.'))); }, child: const Text('Confirmar SOS'))]));

class PageHeading extends StatelessWidget { const PageHeading(this.title, this.subtitle, {super.key}); final String title, subtitle; @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 5), Text(subtitle, style: const TextStyle(color: muted))])); }
class StatCard extends StatelessWidget { const StatCard({super.key, required this.title, required this.value, required this.unit, required this.icon, this.color = blue, this.caption}); final String title, value, unit; final IconData icon; final Color color; final String? caption; @override Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(17), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Text(title, style: const TextStyle(color: muted, fontWeight: FontWeight.w600, fontSize: 12))), Icon(icon, color: color)]), const SizedBox(height: 15), Text.rich(TextSpan(children: [TextSpan(text: value, style: const TextStyle(fontSize: 29, fontWeight: FontWeight.w800)), TextSpan(text: ' $unit', style: const TextStyle(color: muted, fontSize: 12))])), if (caption != null) Padding(padding: const EdgeInsets.only(top: 5), child: Text(caption!, style: const TextStyle(color: muted, fontSize: 11)))]))); }

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.userName, required this.readings, required this.bluetooth, required this.go}); final String userName; final List<Reading> readings; final VitaBluetoothService bluetooth; final ValueChanged<int> go;
  @override Widget build(BuildContext context) { final r = readings.first; final first = userName.trim().split(' ').first; final connected = bluetooth.isConnected; return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [PageHeading('Olá, $first', 'Aqui está o resumo do seu monitoramento.'), Wrap(spacing: 12, runSpacing: 12, children: [SizedBox(width: 230, child: StatCard(title: 'Dispositivo', value: connected ? 'Online' : 'Offline', unit: '', icon: Icons.bluetooth, color: connected ? const Color(0xFF16A36A) : muted, caption: connected ? 'Conectado via Bluetooth LE' : 'Você pode conectar depois')), SizedBox(width: 230, child: StatCard(title: 'Frequência Cardíaca', value: '${r.heart}', unit: 'bpm', icon: Icons.favorite, color: const Color(0xFFEF3E45), caption: 'Última medição demonstrativa')), SizedBox(width: 230, child: StatCard(title: 'Temperatura', value: r.temperature.toStringAsFixed(1).replaceAll('.', ','), unit: '°C', icon: Icons.thermostat, color: const Color(0xFF7954E9))), SizedBox(width: 230, child: StatCard(title: 'Oxigenação (SpO₂)', value: '${r.spo2}', unit: '%', icon: Icons.water_drop, color: const Color(0xFF16A36A)))]), const SizedBox(height: 16), LayoutBuilder(builder: (context, c) => Wrap(spacing: 14, runSpacing: 14, children: [SizedBox(width: c.maxWidth > 740 ? c.maxWidth * .59 : c.maxWidth, child: Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Monitoramento em Tempo Real', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), const SizedBox(height: 8), const Row(children: [LegendDot(color: blue, label: 'Frequência cardíaca'), LegendDot(color: Color(0xFF7954E9), label: 'Temperatura')]), const SizedBox(height: 18), SizedBox(height: 210, child: VitalChart(readings: readings)), Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => go(2), child: const Text('Ver gráficos completos →')))])))), SizedBox(width: c.maxWidth > 740 ? c.maxWidth * .37 : c.maxWidth, child: Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Resumo de Hoje', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 16), _summary(Icons.thermostat, 'Temperatura Corporal', '${r.temperature.toStringAsFixed(1)} °C'), _summary(Icons.favorite, 'Frequência Cardíaca', '${r.heart} bpm'), _summary(Icons.water_drop, 'SpO₂ (Oxigenação)', '${r.spo2}%'), const Divider(), const Text('Calendário de Uso', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8), CalendarMini()]))))])), const SizedBox(height: 14), Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Ações Rápidas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 12), Wrap(spacing: 10, runSpacing: 8, children: [OutlinedButton.icon(onPressed: () => go(1), icon: const Icon(Icons.history), label: const Text('Meu Histórico')), OutlinedButton.icon(onPressed: () => go(3), icon: const Icon(Icons.picture_as_pdf), label: const Text('Gerar Relatório')), OutlinedButton.icon(onPressed: () => go(5), icon: const Icon(Icons.watch), label: const Text('Dispositivo')), OutlinedButton.icon(onPressed: () => Share.share('Resumo V.I.T.A. demonstrativo: temperatura ${r.temperature} °C, frequência cardíaca ${r.heart} bpm e SpO₂ ${r.spo2}%.', subject: 'Resumo V.I.T.A.'), icon: const Icon(Icons.share), label: const Text('Compartilhar'))])])))]); }
  Widget _summary(IconData icon, String title, String value) => Padding(padding: const EdgeInsets.only(bottom: 14), child: Row(children: [Icon(icon, color: blue), const SizedBox(width: 10), Expanded(child: Text(title, style: const TextStyle(fontSize: 12))), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))]));
}
class LegendDot extends StatelessWidget { const LegendDot({super.key, required this.color, required this.label}); final Color color; final String label; @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(right: 12), child: Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 5), Text(label, style: const TextStyle(fontSize: 10, color: muted))])); }
class VitalChart extends StatelessWidget { const VitalChart({super.key, required this.readings}); final List<Reading> readings; @override Widget build(BuildContext context) => LineChart(LineChartData(minY: 55, maxY: 115, gridData: const FlGridData(show: true, drawVerticalLine: false), borderData: FlBorderData(show: false), titlesData: const FlTitlesData(leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28)), bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false))), lineBarsData: [LineChartBarData(isCurved: true, color: blue, barWidth: 3, dotData: const FlDotData(show: false), spots: readings.reversed.toList().asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.heart.toDouble())).toList())])); } }
class CalendarMini extends StatefulWidget { const CalendarMini({super.key}); @override State<CalendarMini> createState() => _CalendarMiniState(); }
class _CalendarMiniState extends State<CalendarMini> { DateTime month = DateTime.now(); DateTime? chosen; @override Widget build(BuildContext context) { final count = DateTime(month.year, month.month + 1, 0).day; final offset = DateTime(month.year, month.month, 1).weekday % 7; final fmt = DateFormat('MMMM yyyy', 'pt_BR'); return Column(children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [IconButton(onPressed: () => setState(() => month = DateTime(month.year, month.month - 1)), icon: const Icon(Icons.chevron_left)), Text(toBeginningOfSentenceCase(fmt.format(month))!, style: const TextStyle(fontWeight: FontWeight.bold)), IconButton(onPressed: () => setState(() => month = DateTime(month.year, month.month + 1)), icon: const Icon(Icons.chevron_right))]), const Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [Text('D'), Text('S'), Text('T'), Text('Q'), Text('Q'), Text('S'), Text('S')]), const SizedBox(height: 5), GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: ((offset + count + 6) ~/ 7) * 7, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7), itemBuilder: (_, i) { final day = i - offset + 1; if (day < 1 || day > count) return const SizedBox(); final date = DateTime(month.year, month.month, day); final active = chosen == date || (chosen == null && DateUtils.isSameDay(date, DateTime.now())); return InkWell(onTap: () => setState(() => chosen = date), child: Container(margin: const EdgeInsets.all(2), decoration: BoxDecoration(color: active ? blue : null, shape: BoxShape.circle), alignment: Alignment.center, child: Text('$day', style: TextStyle(fontSize: 11, color: active ? Colors.white : null)))); })]); } }

class HistoryPage extends StatefulWidget { const HistoryPage({super.key, required this.readings}); final List<Reading> readings; @override State<HistoryPage> createState() => _HistoryPageState(); }
class _HistoryPageState extends State<HistoryPage> { String filter = 'Todos'; String query = ''; @override Widget build(BuildContext context) { final list = widget.readings.where((r) => (filter == 'Todos' || r.status == filter) && DateFormat('dd/MM/yyyy').format(r.date).contains(query)).toList(); return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const PageHeading('Meu Histórico', 'Consulte e filtre as medições registradas.'), Wrap(spacing: 10, runSpacing: 8, children: [SizedBox(width: 220, child: TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar por data'), onChanged: (v) => setState(() => query = v))), SizedBox(width: 170, child: DropdownButtonFormField<String>(value: filter, decoration: const InputDecoration(labelText: 'Classificação'), items: ['Todos', 'Normal', 'Atenção'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => filter = v ?? 'Todos')))]), const SizedBox(height: 16), Card(child: Column(children: [for (final r in list) ListTile(leading: CircleAvatar(backgroundColor: r.status == 'Normal' ? const Color(0xFFE5F8EE) : const Color(0xFFFFEAEB), child: Icon(r.status == 'Normal' ? Icons.check : Icons.warning_amber, color: r.status == 'Normal' ? Colors.green : Colors.red)), title: Text(DateFormat('dd/MM/yyyy').format(r.date), style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('Temperatura: ${r.temperature} °C  ·  FC: ${r.heart} bpm  ·  SpO₂: ${r.spo2}%'), trailing: Text(r.status, style: TextStyle(color: r.status == 'Normal' ? Colors.green : Colors.orange, fontWeight: FontWeight.bold)),), if (list.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('Nenhum registro encontrado.'))]))]); } }

class ChartsPage extends StatefulWidget { const ChartsPage({super.key, required this.readings}); final List<Reading> readings; @override State<ChartsPage> createState() => _ChartsPageState(); }
class _ChartsPageState extends State<ChartsPage> { String metric = 'Frequência cardíaca'; @override Widget build(BuildContext context) { final values = widget.readings.reversed.toList(); final spots = values.asMap().entries.map((e) => FlSpot(e.key.toDouble(), metric == 'Frequência cardíaca' ? e.value.heart.toDouble() : metric == 'Temperatura' ? e.value.temperature : e.value.spo2.toDouble())).toList(); return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const PageHeading('Gráficos', 'Visualize a evolução dos seus sinais vitais.'), DropdownButtonFormField<String>(value: metric, decoration: const InputDecoration(labelText: 'Parâmetro'), items: ['Frequência cardíaca', 'Temperatura', 'SpO₂'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => metric = v ?? metric)), const SizedBox(height: 14), Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(metric, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 24), SizedBox(height: 270, child: LineChart(LineChartData(gridData: const FlGridData(show: true), borderData: FlBorderData(show: false), lineBarsData: [LineChartBarData(isCurved: true, color: blue, barWidth: 3, spots: spots, dotData: const FlDotData(show: true))])))]))), const SizedBox(height: 12), Text('Os valores apresentados são dados fictícios de demonstração.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted))]); } }

class ReportsPage extends StatelessWidget { const ReportsPage({super.key, required this.readings}); final List<Reading> readings; Future<void> _pdf(BuildContext context) async { final doc = pw.Document(); doc.addPage(pw.MultiPage(build: (_) => [pw.Header(level: 0, child: pw.Text('V.I.T.A. · Relatório de monitoramento')), pw.Text('Relatório demonstrativo gerado em ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}'), pw.SizedBox(height: 18), pw.Table.fromTextArray(headers: ['Data', 'Temperatura', 'FC', 'SpO₂', 'Classificação'], data: readings.map((r) => [DateFormat('dd/MM/yyyy').format(r.date), '${r.temperature} °C', '${r.heart} bpm', '${r.spo2}%', r.status]).toList()), pw.SizedBox(height: 14), pw.Text('Documento demonstrativo. Não substitui avaliação profissional.') ])); await Printing.layoutPdf(onLayout: (_) async => doc.save()); }
  @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const PageHeading('Relatórios', 'Gere documentos com o histórico de monitoramento.'), Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.picture_as_pdf, color: blue, size: 38), const SizedBox(height: 12), const Text('Relatório completo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const Text('Inclui data, temperatura, frequência cardíaca, SpO₂ e classificação.'), const SizedBox(height: 16), FilledButton.icon(onPressed: () => _pdf(context), icon: const Icon(Icons.download), label: const Text('Gerar relatório PDF'))])))]);

class AlertsPage extends StatelessWidget { const AlertsPage({super.key}); @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const PageHeading('Alertas', 'Acompanhe notificações e alterações demonstrativas.'), _alert('Temperatura elevada', '37,9 °C · Exemplo de alerta', true), _alert('Frequência cardíaca normal', '72 bpm · Registro de demonstração', false), _alert('Frequência cardíaca elevada', '112 bpm · Exemplo de alerta', true), _alert('Oxigenação normal', '98% · Registro de demonstração', false)]); Widget _alert(String title, String detail, bool warning) => Card(child: ListTile(leading: Icon(warning ? Icons.warning_amber_rounded : Icons.check_circle_outline, color: warning ? Colors.orange : Colors.green), title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(detail), trailing: const Icon(Icons.chevron_right))); }

class DevicePage extends StatelessWidget {
  const DevicePage({super.key, required this.bluetooth});
  final VitaBluetoothService bluetooth;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: bluetooth,
    builder: (context, _) {
      final connected = bluetooth.isConnected;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const PageHeading('Dispositivo', 'Conecte sua pulseira V.I.T.A. por Bluetooth quando estiver disponível.'),
        Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
          Icon(Icons.watch, size: 62, color: connected ? Colors.green : blue),
          const SizedBox(height: 8),
          Text(connected ? (bluetooth.connectedDevice?.platformName.isNotEmpty == true ? bluetooth.connectedDevice!.platformName : 'Dispositivo V.I.T.A.') : 'Nenhum dispositivo conectado', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 5),
          Text(connected ? '● Conectado via Bluetooth LE' : 'Você pode usar o aplicativo normalmente sem o dispositivo.', style: TextStyle(color: connected ? Colors.green : muted), textAlign: TextAlign.center),
          const Divider(height: 30),
          ListTile(leading: const Icon(Icons.bluetooth), title: const Text('Bluetooth do telefone'), trailing: Text(bluetooth.adapterStateLabel)),
          ListTile(leading: const Icon(Icons.link), title: const Text('Conexão V.I.T.A.'), trailing: Text(connected ? 'Conectado' : 'Desconectado')),
          if (connected) ListTile(leading: const Icon(Icons.memory), title: const Text('Serviços GATT encontrados'), trailing: Text('${bluetooth.discoveredServices.length}')),
          const SizedBox(height: 8),
          if (connected) FilledButton.tonalIcon(onPressed: bluetooth.disconnect, icon: const Icon(Icons.bluetooth_disabled), label: const Text('Desconectar'))
          else FilledButton.icon(onPressed: bluetooth.scanning ? bluetooth.stopScan : bluetooth.startScan, icon: Icon(bluetooth.scanning ? Icons.stop : Icons.bluetooth_searching), label: Text(bluetooth.scanning ? 'Parar busca' : 'Procurar dispositivos')),
          if (bluetooth.connecting) const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()),
          if (bluetooth.scanning) const Padding(padding: EdgeInsets.only(top: 12), child: Text('Procurando dispositivos próximos…')),
          if (bluetooth.errorMessage != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(bluetooth.errorMessage!, style: const TextStyle(color: Colors.deepOrange))),
          if (bluetooth.devices.isNotEmpty) ...[
            const Divider(height: 28),
            const Align(alignment: Alignment.centerLeft, child: Text('Dispositivos encontrados', style: TextStyle(fontWeight: FontWeight.bold))),
            ...bluetooth.devices.map((result) => ListTile(leading: const Icon(Icons.bluetooth), title: Text(result.device.platformName.isEmpty ? 'Dispositivo sem nome' : result.device.platformName), subtitle: Text(result.device.remoteId.str), trailing: Text('${result.rssi} dBm'), onTap: bluetooth.connecting ? null : () => bluetooth.connect(result.device))),
          ],
          const SizedBox(height: 12),
          const Text('As medições exibidas nas outras telas permanecem disponíveis mesmo sem conexão. A leitura real dos sensores será ativada após definirmos o serviço e as características BLE do firmware ESP32.', style: TextStyle(color: muted, fontSize: 12)),
        ]))),
      ]);
    },
  );
}

class SettingsPage extends StatelessWidget { const SettingsPage({super.key, required this.dark, required this.onTheme}); final bool dark; final ValueChanged<bool> onTheme; @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const PageHeading('Configurações', 'Personalize sua experiência no V.I.T.A.'), Card(child: Column(children: [SwitchListTile(title: const Text('Tema escuro'), subtitle: const Text('Altere a aparência do aplicativo'), value: dark, onChanged: onTheme), const Divider(height: 1), const ListTile(leading: Icon(Icons.notifications_outlined), title: Text('Notificações'), subtitle: Text('Preferências de alertas locais')), const ListTile(leading: Icon(Icons.monitor_heart_outlined), title: Text('Monitoramento'), subtitle: Text('Parâmetros demonstrativos')), const ListTile(leading: Icon(Icons.lock_outline), title: Text('Privacidade e segurança'), subtitle: Text('Dados armazenados localmente nesta versão')), const ListTile(leading: Icon(Icons.accessibility_new), title: Text('Acessibilidade'), subtitle: Text('Compatível com escala de texto do sistema'))]))]); }

class HelpPage extends StatelessWidget { const HelpPage({super.key}); @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const PageHeading('Ajuda e Suporte', 'Informações sobre o aplicativo.'), const Card(child: Padding(padding: EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Sobre o V.I.T.A.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), SizedBox(height: 8), Text('V.I.T.A. é um protótipo de monitoramento de sinais vitais. Esta versão móvel reproduz a experiência do site com dados demonstrativos.'), SizedBox(height: 18), Text('Importante', style: TextStyle(fontWeight: FontWeight.bold)), SizedBox(height: 6), Text('Este aplicativo não realiza diagnóstico, não substitui avaliação profissional e ainda não está conectado aos sensores físicos ou à API.')])))]); }

class LoginScreen extends StatefulWidget { const LoginScreen({super.key, required this.onLogin}); final ValueChanged<String> onLogin; @override State<LoginScreen> createState() => _LoginScreenState(); }
class _LoginScreenState extends State<LoginScreen> { final name = TextEditingController(); final cpf = TextEditingController(); bool register = false; @override Widget build(BuildContext context) => Scaffold(body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: Card(child: Padding(padding: const EdgeInsets.all(26), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [const Center(child: VitaBrand()), const SizedBox(height: 28), Text(register ? 'Criar conta' : 'Bem-vindo ao V.I.T.A.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800)), const SizedBox(height: 6), Text(register ? 'Preencha seus dados para continuar.' : 'Entre para acessar seu monitoramento.', textAlign: TextAlign.center, style: const TextStyle(color: muted)), const SizedBox(height: 24), TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome completo', prefixIcon: Icon(Icons.person_outline))), const SizedBox(height: 12), TextField(controller: cpf, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'CPF', prefixIcon: Icon(Icons.badge_outlined))), const SizedBox(height: 18), FilledButton(onPressed: () { final n = name.text.trim(); if (n.isEmpty || cpf.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe nome e CPF para continuar.'))); return; } widget.onLogin(n); }, child: Text(register ? 'Cadastrar e entrar' : 'Entrar')), TextButton(onPressed: () => setState(() => register = !register), child: Text(register ? 'Já tenho uma conta · Entrar' : 'Não tem conta? Cadastre-se')), const SizedBox(height: 12), const Text('Versão demonstrativa: a autenticação não valida credenciais nem se conecta a um servidor.', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: muted))])))))); }
}
