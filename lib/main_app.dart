// main_app.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'schedule_screen.dart';
import 'reminder_screen.dart';
import 'summary_screen.dart';
import 'login_screen.dart';
import 'notification_service.dart';

class MainApp extends StatefulWidget {
  final String elderlyId;
  final String elderlyName;

  const MainApp({super.key, required this.elderlyId, required this.elderlyName});

  @override
  State<MainApp> createState() {
    return _MainAppState();
  }
}

class _MainAppState extends State<MainApp> with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _isEnsuring = false;
  StreamSubscription<QuerySnapshot>? _reminderSub;
  final Map<String, String?> _creatorCache = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ensureTodayMealReminders();
    _listenReminders();
  }

  @override
  void dispose() {
    _reminderSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _ensureTodayMealReminders();
    }
  }

  // ---------- แจ้งเตือน ----------

  void _listenReminders() {
    _reminderSub = FirebaseFirestore.instance
        .collection('reminders')
        .where('elderlyId', isEqualTo: widget.elderlyId)
        .snapshots()
        .listen(_syncNotifications);
  }

  Future<String?> _creatorOf(String medicineId) async {
    if (_creatorCache.containsKey(medicineId)) return _creatorCache[medicineId];

    DocumentSnapshot snap =
    await FirebaseFirestore.instance.collection('medicines').doc(medicineId).get();

    String? creator;
    if (snap.exists) {
      creator = (snap.data() as Map<String, dynamic>)['createdByUid'];
    }
    _creatorCache[medicineId] = creator;
    return creator;
  }

  Future<void> _syncNotifications(QuerySnapshot snap) async {
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    for (var change in snap.docChanges) {
      String docId = change.doc.id;

      if (change.type == DocumentChangeType.removed) {
        await NotificationService.cancel(docId);
        continue;
      }

      final data = change.doc.data() as Map<String, dynamic>?;
      if (data == null) continue;

      bool isDone = data['isDone'] ?? false;
      bool hidden = data['hidden'] ?? false;
      if (isDone || hidden) {
        await NotificationService.cancel(docId);
        continue;
      }

      Timestamp? ts = data['scheduledTime'];
      if (ts == null) continue;

      String medicineId = data['medicineId'] ?? '';
      if (medicineId.isEmpty) continue;

      String? creator = await _creatorOf(medicineId);
      if (creator != uid) continue;

      await NotificationService.schedule(
        docId: docId,
        title: 'ถึงเวลากินยา',
        body: '${data['name'] ?? ''} • ${widget.elderlyName}',
        time: ts.toDate(),
      );
    }
  }

  // ---------- รายการประจำวัน ----------

  DateTime _combineTodayWithTime(String hhmm) {
    List<String> parts = hhmm.split(':');
    DateTime now = DateTime.now();
    return DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
  }

  String _todayKey() {
    DateTime now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  bool _hasStarted(Map<String, dynamic> medData, DateTime today) {
    Timestamp? ts = medData['startDate'];
    if (ts == null) return true;
    DateTime s = ts.toDate();
    DateTime startDay = DateTime(s.year, s.month, s.day);
    return !today.isBefore(startDay);
  }

  Future<void> _ensureTodayMealReminders() async {
    if (_isEnsuring) return;
    _isEnsuring = true;

    try {
      DateTime now = DateTime.now();
      DateTime today = DateTime(now.year, now.month, now.day);
      String todayKey = _todayKey();

      QuerySnapshot mealMedicineSnap = await FirebaseFirestore.instance
          .collection('medicines')
          .where('elderlyId', isEqualTo: widget.elderlyId)
          .where('scheduleType', isEqualTo: 'meal')
          .get();

      for (var medDoc in mealMedicineSnap.docs) {
        final medData = medDoc.data() as Map<String, dynamic>;
        int remaining = medData['remainingQuantity'] ?? 0;
        if (remaining <= 0) continue;
        if (!_hasStarted(medData, today)) continue;

        List meals = medData['meals'] ?? [];
        Map<String, dynamic> mealTimes = medData['mealTimes'] ?? {};
        String mealTiming = medData['mealTiming'] ?? 'before';
        String timingLabel = mealTiming == 'before'
            ? 'ก่อนอาหาร'
            : mealTiming == 'after'
            ? 'หลังอาหาร'
            : 'พร้อมอาหาร';

        for (String meal in meals) {
          QuerySnapshot existing = await FirebaseFirestore.instance
              .collection('reminders')
              .where('medicineId', isEqualTo: medDoc.id)
              .where('mealName', isEqualTo: meal)
              .where('dateKey', isEqualTo: todayKey)
              .get();

          if (existing.docs.isNotEmpty) continue;

          String? timeStr = mealTimes[meal];
          if (timeStr == null) continue;

          DateTime scheduledTime = _combineTodayWithTime(timeStr);

          await FirebaseFirestore.instance.collection('reminders').add({
            'elderlyId': widget.elderlyId,
            'medicineId': medDoc.id,
            'name': medData['name'] ?? '',
            'time': '$meal • $timingLabel ($timeStr)',
            'scheduleType': 'meal',
            'mealName': meal,
            'scheduledTime': Timestamp.fromDate(scheduledTime),
            'dateKey': todayKey,
            'isDone': false,
            'isOverdue': false,
          });
        }
      }

      QuerySnapshot bedMedicineSnap = await FirebaseFirestore.instance
          .collection('medicines')
          .where('elderlyId', isEqualTo: widget.elderlyId)
          .where('scheduleType', isEqualTo: 'beforeBed')
          .get();

      for (var medDoc in bedMedicineSnap.docs) {
        final medData = medDoc.data() as Map<String, dynamic>;
        int remaining = medData['remainingQuantity'] ?? 0;
        if (remaining <= 0) continue;
        if (!_hasStarted(medData, today)) continue;

        String? bedTimeStr = medData['bedTime'];
        if (bedTimeStr == null) continue;

        QuerySnapshot existing = await FirebaseFirestore.instance
            .collection('reminders')
            .where('medicineId', isEqualTo: medDoc.id)
            .where('scheduleType', isEqualTo: 'beforeBed')
            .where('dateKey', isEqualTo: todayKey)
            .get();

        if (existing.docs.isNotEmpty) continue;

        DateTime bedDateTime = _combineTodayWithTime(bedTimeStr);
        DateTime scheduledTime = bedDateTime.subtract(const Duration(minutes: 20));

        await FirebaseFirestore.instance.collection('reminders').add({
          'elderlyId': widget.elderlyId,
          'medicineId': medDoc.id,
          'name': medData['name'] ?? '',
          'time': 'ก่อนนอน 15-30 นาที (ราว $bedTimeStr)',
          'scheduleType': 'beforeBed',
          'scheduledTime': Timestamp.fromDate(scheduledTime),
          'dateKey': todayKey,
          'isDone': false,
          'isOverdue': false,
        });
      }
    } finally {
      _isEnsuring = false;
    }
  }

  // ---------- UI ----------

  Future<void> _logout() async {
    await NotificationService.cancelAll();
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
      );
    }
  }

  Widget _buildReminderIconWithBadge() {
    final reminders = FirebaseFirestore.instance
        .collection('reminders')
        .where('elderlyId', isEqualTo: widget.elderlyId)
        .where('isDone', isEqualTo: false);

    return StreamBuilder<QuerySnapshot>(
      stream: reminders.snapshots(),
      builder: (context, snapshot) {
        int overdueCount = 0;

        if (snapshot.hasData) {
          DateTime now = DateTime.now();
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['hidden'] == true) continue;
            Timestamp? ts = data['scheduledTime'];
            if (ts != null && ts.toDate().isBefore(now)) {
              overdueCount++;
            }
          }
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.notifications),
            if (overdueCount > 0)
              Positioned(
                right: -6,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    '$overdueCount',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryIconWithBadge() {
    final medicines = FirebaseFirestore.instance
        .collection('medicines')
        .where('elderlyId', isEqualTo: widget.elderlyId);

    return StreamBuilder<QuerySnapshot>(
      stream: medicines.snapshots(),
      builder: (context, snapshot) {
        int lowStockCount = 0;

        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            int total = data['totalQuantity'] ?? 0;
            int remaining = data['remainingQuantity'] ?? 0;
            if (total > 0 && remaining / total < 0.3) {
              lowStockCount++;
            }
          }
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.bar_chart),
            if (lowStockCount > 0)
              Positioned(
                right: -6,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    '$lowStockCount',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      ScheduleScreen(elderlyId: widget.elderlyId),
      ReminderScreen(elderlyId: widget.elderlyId),
      SummaryScreen(elderlyId: widget.elderlyId),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('กำลังดูแล: ${widget.elderlyName}'),
        backgroundColor: const Color(0xFF0D3B3E),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: const Color(0xFF0D3B3E),
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.schedule), label: 'ตั้งเวลายา'),
          BottomNavigationBarItem(icon: _buildReminderIconWithBadge(), label: 'แจ้งเตือน'),
          BottomNavigationBarItem(icon: _buildSummaryIconWithBadge(), label: 'สรุปสถานะ'),
        ],
      ),
    );
  }
}