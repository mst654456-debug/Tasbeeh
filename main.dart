import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:adhan/adhan.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

const green = Color(0xFF126B50);
const gold = Color(0xFFD6AE55);
final notifications = FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Africa/Cairo'));
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  await notifications.initialize(const InitializationSettings(android: android));
  runApp(const WardiApp());
}

class WardiApp extends StatelessWidget {
  const WardiApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'وردي وتسبيحي',
    theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: green), scaffoldBackgroundColor: const Color(0xFFF7F6F0)),
    home: const HomePage(),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int tab = 0, count = 0, goal = 100;
  String selectedDhikr = 'سبحان الله';
  String locationText = 'لم يتم تحديد الموقع بعد';
  List<String> adhkar = ['سبحان الله', 'الحمد لله', 'الله أكبر', 'لا إله إلا الله', 'أستغفر الله', 'اللهم صل وسلم على نبينا محمد'];
  List<String> duas = [];
  final Map<String, int> duaCounts = {};
  final Map<String, int> duaGoals = {};
  final controller = TextEditingController();
  SharedPreferences? prefs;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    prefs = await SharedPreferences.getInstance();
    setState(() {
      count = prefs!.getInt('count') ?? 0;
      goal = prefs!.getInt('goal') ?? 100;
      selectedDhikr = prefs!.getString('dhikr') ?? 'سبحان الله';
      duas = prefs!.getStringList('duas') ?? [];
      for (final d in duas) { duaCounts[d] = prefs!.getInt('c_$d') ?? 0; duaGoals[d] = prefs!.getInt('g_$d') ?? 100; }
    });
  }

  Future<void> _save() async {
    await prefs?.setInt('count', count); await prefs?.setInt('goal', goal); await prefs?.setString('dhikr', selectedDhikr);
    for (final d in duas) { await prefs?.setInt('c_$d', duaCounts[d] ?? 0); await prefs?.setInt('g_$d', duaGoals[d] ?? 100); }
  }

  void _increment() { setState(() => count++); _save(); }

  Future<void> _addDua() async {
    final value = controller.text.trim(); if (value.isEmpty) return;
    setState(() { if (!duas.contains(value)) { duas.add(value); duaCounts[value] = 0; duaGoals[value] = 100; } controller.clear(); });
    await prefs?.setStringList('duas', duas); await _save();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _schedulePrayerNotifications() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) throw Exception('فعّل خدمة الموقع في الهاتف');
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) throw Exception('اسمح للتطبيق بالوصول إلى الموقع');
      final p = await Geolocator.getCurrentPosition();
      final androidPlugin = notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
      final coordinates = Coordinates(p.latitude, p.longitude);
      final params = CalculationMethod.egyptian.getParameters();
      final times = PrayerTimes(coordinates, DateComponents.from(DateTime.now()), params);
      final names = ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء'];
      final dates = [times.fajr, times.dhuhr, times.asr, times.maghrib, times.isha];
      await notifications.cancelAll();
      for (var i = 0; i < dates.length; i++) {
        if (!dates[i].isAfter(DateTime.now())) continue;
        await notifications.zonedSchedule(i + 1, 'حان وقت صلاة ${names[i]}', 'حيّ على الصلاة', tz.TZDateTime.from(dates[i], tz.local),
          const NotificationDetails(android: AndroidNotificationDetails('prayer_times', 'مواقيت الصلاة', channelDescription: 'تنبيهات دخول أوقات الصلاة', importance: Importance.max, priority: Priority.high)),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime);
      }
      setState(() => locationText = 'تم تحديد الموقع وإعداد تنبيهات الصلوات المتبقية اليوم');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إعداد تنبيهات الصلاة لليوم')));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إعداد المواقيت: $e'))); }
  }

  void _showAddDua() {
    showDialog(context: context, builder: (_) => AlertDialog(title: const Text('إضافة ورد دعاء'), content: TextField(controller: controller, maxLines: 4, decoration: const InputDecoration(hintText: 'اكتب الدعاء هنا', border: OutlineInputBorder())), actions: [TextButton(onPressed: () { controller.clear(); Navigator.pop(context); }, child: const Text('إلغاء')), FilledButton(onPressed: _addDua, child: const Text('حفظ'))]));
  }

  Widget _counterCard() => Card(color: green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), child: Padding(padding: const EdgeInsets.all(22), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Text('ورد التسبيح', style: TextStyle(color: Colors.white70, fontSize: 17)), const SizedBox(height: 10),
    DropdownButton<String>(value: selectedDhikr, dropdownColor: green, style: const TextStyle(color: Colors.white, fontSize: 18), underline: const SizedBox(), items: adhkar.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(), onChanged: (v) { if (v != null) setState(() { selectedDhikr = v; count = 0; }); _save(); }),
    const SizedBox(height: 8), Text('$count', style: const TextStyle(color: Colors.white, fontSize: 58, fontWeight: FontWeight.bold)), Text('الهدف: $goal', style: const TextStyle(color: Colors.white70)), const SizedBox(height: 18),
    SizedBox(width: 170, height: 170, child: FilledButton(style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: Colors.black, shape: const CircleBorder(), elevation: 4), onPressed: _increment, child: const Text('اضغط للتسبيح', textAlign: TextAlign.center, style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)))),
    const SizedBox(height: 12), Row(mainAxisAlignment: MainAxisAlignment.center, children: [OutlinedButton.icon(onPressed: () { setState(() => count = 0); _save(); }, icon: const Icon(Icons.refresh, color: Colors.white), label: const Text('تصفير', style: TextStyle(color: Colors.white))), const SizedBox(width: 10), OutlinedButton.icon(onPressed: _chooseGoal, icon: const Icon(Icons.flag, color: Colors.white), label: const Text('الهدف', style: TextStyle(color: Colors.white)))])
  ])));

  Future<void> _chooseGoal() async {
    int temp = goal;
    final value = await showDialog<int>(context: context, builder: (_) => AlertDialog(title: const Text('تحديد الهدف'), content: StatefulBuilder(builder: (c, setD) => DropdownButton<int>(value: temp, items: [33, 100, 500, 1000].map((n) => DropdownMenuItem(value: n, child: Text('$n'))).toList(), onChanged: (n) { if (n != null) setD(() => temp = n); })), actions: [TextButton(onPressed: () => Navigator.pop(context, temp), child: const Text('حفظ'))]);
    if (value != null) { setState(() => goal = value); _save(); }
  }

  Widget _duaTab() => Column(children: [const SizedBox(height: 12), FilledButton.icon(onPressed: _showAddDua, icon: const Icon(Icons.add), label: const Text('إضافة دعاء جديد')), const SizedBox(height: 8), Expanded(child: duas.isEmpty ? const Center(child: Text('لم تضف أورادًا بعد. اكتب دعاءك وابدأ وردك.')) : ListView.builder(itemCount: duas.length, itemBuilder: (_, i) {
    final d = duas[i]; return Card(child: ListTile(title: Text(d, textDirection: TextDirection.rtl), subtitle: Text('التكرار: ${duaCounts[d] ?? 0} / ${duaGoals[d] ?? 100}'), trailing: Wrap(spacing: 4, children: [IconButton(onPressed: () => setState(() { duaCounts[d] = (duaCounts[d] ?? 0) + 1; _save(); }), icon: const Icon(Icons.add_circle, color: green)), IconButton(onPressed: () => _deleteDua(d), icon: const Icon(Icons.delete_outline))])));
  }))]);

  Future<void> _deleteDua(String d) async { setState(() { duas.remove(d); duaCounts.remove(d); duaGoals.remove(d); }); await prefs?.setStringList('duas', duas); await prefs?.remove('c_$d'); await prefs?.remove('g_$d'); }

  Widget _prayerTab() => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.mosque, size: 76, color: green), const SizedBox(height: 16), const Text('مواقيت الصلاة حسب موقعك', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)), const SizedBox(height: 10), Text(locationText, textAlign: TextAlign.center), const SizedBox(height: 20), FilledButton.icon(onPressed: _schedulePrayerNotifications, icon: const Icon(Icons.my_location), label: const Text('تحديد الموقع وإعداد التنبيهات')), const SizedBox(height: 10), const Text('طريقة الحساب: الهيئة المصرية العامة للمساحة', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54))])));

  @override
  Widget build(BuildContext context) {
    final pages = [_counterCard(), _duaTab(), _prayerTab()];
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(appBar: AppBar(title: const Text('🌿 وردي وتسبيحي'), backgroundColor: green, foregroundColor: Colors.white, centerTitle: true), body: SafeArea(child: Padding(padding: const EdgeInsets.all(14), child: pages[tab])), bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (v) => setState(() => tab = v), destinations: const [NavigationDestination(icon: Icon(Icons.touch_app), label: 'التسبيح'), NavigationDestination(icon: Icon(Icons.menu_book), label: 'أورادي'), NavigationDestination(icon: Icon(Icons.mosque), label: 'الصلاة')])));
  }
}
