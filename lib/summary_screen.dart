// summary_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SummaryScreen extends StatelessWidget {
  final String elderlyId;

  const SummaryScreen({super.key, required this.elderlyId});

  Future<void> _removeMedicine(String medicineId) async {
    await FirebaseFirestore.instance.collection('medicines').doc(medicineId).delete();

    QuerySnapshot relatedReminders = await FirebaseFirestore.instance
        .collection('reminders')
        .where('medicineId', isEqualTo: medicineId)
        .get();

    for (var doc in relatedReminders.docs) {
      await doc.reference.delete();
    }
  }

  String _dateKeyFor(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Set<String> _allowedDateKeys() {
    DateTime now = DateTime.now();
    Set<String> keys = {};
    for (int i = 0; i < 7; i++) {
      keys.add(_dateKeyFor(now.subtract(Duration(days: i))));
    }
    return keys;
  }

  // จัดอันดับความสำคัญแบบเดียวกับหน้าแจ้งเตือน: เกินกำหนด > ใกล้เวลาสุด > เสร็จแล้ว
  int _sortRank(bool isDone, bool isOverdue, DateTime? scheduledTime) {
    if (isDone) return 3;
    if (isOverdue) return 0;
    if (scheduledTime != null) return 1;
    return 2;
  }

  List<QueryDocumentSnapshot> _sortHistory(List<QueryDocumentSnapshot> docs) {
    DateTime now = DateTime.now();
    List<QueryDocumentSnapshot> sorted = List.from(docs);

    sorted.sort((a, b) {
      final dataA = a.data() as Map<String, dynamic>;
      final dataB = b.data() as Map<String, dynamic>;

      bool isDoneA = dataA['isDone'] ?? false;
      bool isDoneB = dataB['isDone'] ?? false;

      Timestamp? tsA = dataA['scheduledTime'];
      Timestamp? tsB = dataB['scheduledTime'];
      DateTime? timeA = tsA?.toDate();
      DateTime? timeB = tsB?.toDate();

      bool isOverdueA = !isDoneA && timeA != null && timeA.isBefore(now);
      bool isOverdueB = !isDoneB && timeB != null && timeB.isBefore(now);

      int rankA = _sortRank(isDoneA, isOverdueA, timeA);
      int rankB = _sortRank(isDoneB, isOverdueB, timeB);

      if (rankA != rankB) {
        return rankA.compareTo(rankB);
      }
      if (timeA != null && timeB != null) {
        return timeA.compareTo(timeB);
      }
      if (timeA == null && timeB != null) return 1;
      if (timeA != null && timeB == null) return -1;
      return 0;
    });

    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final medicines = FirebaseFirestore.instance
        .collection('medicines')
        .where('elderlyId', isEqualTo: elderlyId);

    final reminders = FirebaseFirestore.instance
        .collection('reminders')
        .where('elderlyId', isEqualTo: elderlyId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('สรุปสถานะ (ผู้ดูแล)'),
        backgroundColor: const Color(0xFF0D3B3E),
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: medicines.snapshots(),
        builder: (context, medicineSnapshot) {
          if (!medicineSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final medicineDocs = medicineSnapshot.data!.docs;

          return StreamBuilder<QuerySnapshot>(
            stream: reminders.snapshots(),
            builder: (context, reminderSnapshot) {
              if (!reminderSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final reminderDocs = reminderSnapshot.data!.docs;

              List<Map<String, dynamic>> lowStockMeds = [];
              for (var doc in medicineDocs) {
                final data = doc.data() as Map<String, dynamic>;
                int total = data['totalQuantity'] ?? 0;
                int remaining = data['remainingQuantity'] ?? 0;
                if (total > 0 && remaining / total < 0.3) {
                  lowStockMeds.add({'name': data['name'] ?? '', 'remaining': remaining});
                }
              }

              Set<String> allowedKeys = _allowedDateKeys();
              List<QueryDocumentSnapshot> historyDocs = reminderDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                String? dateKey = data['dateKey'];
                return dateKey != null && allowedKeys.contains(dateKey);
              }).toList();

              historyDocs = _sortHistory(historyDocs);

              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  if (lowStockMeds.isNotEmpty) _buildLowStockBox(lowStockMeds),

                  const Text('รายการยา', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  if (medicineDocs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('ยังไม่มีข้อมูล'),
                    )
                  else
                    ...medicineDocs.map((medDoc) => _buildMedicineTile(medDoc, reminderDocs)),

                  const SizedBox(height: 24),
                  _buildHistorySection(historyDocs),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHistorySection(List<QueryDocumentSnapshot> historyDocs) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: const Text('ประวัติการกินยา (สัปดาห์นี้)', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${historyDocs.length} รายการ'),
        children: historyDocs.isEmpty
            ? [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('ไม่มีประวัติในช่วงนี้'),
          ),
        ]
            : historyDocs.map((doc) => _buildHistoryTile(doc)).toList(),
      ),
    );
  }

  Widget _buildLowStockBox(List<Map<String, dynamic>> lowStockMeds) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0D3B3E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber, color: Color(0xFFFFC857)),
              const SizedBox(width: 8),
              const Text(
                'ยาใกล้หมด (ควรสั่งเพิ่ม)',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...lowStockMeds.map((med) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '• ${med['name']} — เหลือ ${med['remaining']} เม็ด',
                style: const TextStyle(color: Colors.white),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMedicineTile(QueryDocumentSnapshot medDoc, List<QueryDocumentSnapshot> reminderDocs) {
    final medData = medDoc.data() as Map<String, dynamic>;

    String name = medData['name'] ?? '';
    String imageUrl = medData['imageUrl'] ?? '';
    int remaining = medData['remainingQuantity'] ?? 0;
    bool isEmpty = remaining <= 0;

    List<QueryDocumentSnapshot> pending = reminderDocs.where((r) {
      final rData = r.data() as Map<String, dynamic>;
      return rData['medicineId'] == medDoc.id && (rData['isDone'] ?? false) == false;
    }).toList();

    pending.sort((a, b) {
      final dataA = a.data() as Map<String, dynamic>;
      final dataB = b.data() as Map<String, dynamic>;
      Timestamp? tsA = dataA['scheduledTime'];
      Timestamp? tsB = dataB['scheduledTime'];
      if (tsA == null && tsB == null) return 0;
      if (tsA == null) return 1;
      if (tsB == null) return -1;
      return tsA.compareTo(tsB);
    });

    String nextDoseText;
    if (pending.isEmpty) {
      nextDoseText = 'ไม่มีรอบถัดไป';
    } else {
      final nextData = pending.first.data() as Map<String, dynamic>;
      Timestamp? ts = nextData['scheduledTime'];
      if (ts != null) {
        DateTime dt = ts.toDate();
        String hh = dt.hour.toString().padLeft(2, '0');
        String mm = dt.minute.toString().padLeft(2, '0');
        nextDoseText = '$hh:$mm น.';
      } else {
        nextDoseText = nextData['time'] ?? '';
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: imageUrl.isEmpty
            ? const CircleAvatar(child: Icon(Icons.medication))
            : CircleAvatar(backgroundImage: NetworkImage(imageUrl)),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          isEmpty ? 'ยาหมดแล้ว' : 'คงเหลือ $remaining เม็ด • รอบถัดไป: $nextDoseText',
          style: TextStyle(color: isEmpty ? Colors.red : null),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _removeMedicine(medDoc.id),
        ),
      ),
    );
  }

  Widget _buildHistoryTile(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    String name = data['name'] ?? '';
    bool isDone = data['isDone'] ?? false;

    Timestamp? ts = data['scheduledTime'];
    String dateTimeText = '';
    if (ts != null) {
      DateTime dt = ts.toDate();
      String dd = dt.day.toString().padLeft(2, '0');
      String mm = dt.month.toString().padLeft(2, '0');
      String hh = dt.hour.toString().padLeft(2, '0');
      String min = dt.minute.toString().padLeft(2, '0');
      dateTimeText = '$dd/$mm $hh:$min';
    }

    bool isOverdue = false;
    if (!isDone && ts != null) {
      isOverdue = ts.toDate().isBefore(DateTime.now());
    }

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (isDone) {
      statusColor = Colors.green;
      statusText = 'กินยาแล้ว';
      statusIcon = Icons.check_circle;
    } else if (isOverdue) {
      statusColor = Colors.red;
      statusText = 'พลาด';
      statusIcon = Icons.error;
    } else {
      statusColor = Colors.grey;
      statusText = 'รอถึงเวลา';
      statusIcon = Icons.schedule;
    }

    return ListTile(
      leading: Icon(statusIcon, color: statusColor),
      title: Text(name),
      subtitle: Text(dateTimeText),
      trailing: Text(
        statusText,
        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
      ),
    );
  }
}