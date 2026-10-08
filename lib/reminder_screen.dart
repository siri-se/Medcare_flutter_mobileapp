// reminder_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'medicine_colors.dart';

class ReminderScreen extends StatefulWidget {
  final String elderlyId;

  const ReminderScreen({super.key, required this.elderlyId});

  @override
  State<ReminderScreen> createState() {
    return _ReminderScreenState();
  }
}

class _ReminderItem {
  final QueryDocumentSnapshot doc;
  final Map<String, dynamic> data;
  final String name;
  final String time;
  final bool isDone;
  final bool isOverdue;
  final bool isFromPreviousDay;
  final String medicineId;
  final DateTime? scheduledTime;
  final int sortRank;

  _ReminderItem({
    required this.doc,
    required this.data,
    required this.name,
    required this.time,
    required this.isDone,
    required this.isOverdue,
    required this.isFromPreviousDay,
    required this.medicineId,
    required this.scheduledTime,
    required this.sortRank,
  });
}

class _ReminderScreenState extends State<ReminderScreen> {
  Future<void> _confirmTaken(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    String medicineId = data['medicineId'] ?? '';
    String scheduleType = data['scheduleType'] ?? '';

    await FirebaseFirestore.instance.collection('reminders').doc(doc.id).update({'isDone': true});

    if (medicineId.isEmpty) return;

    DocumentReference medicineRef = FirebaseFirestore.instance.collection('medicines').doc(medicineId);
    DocumentSnapshot medicineSnap = await medicineRef.get();

    if (!medicineSnap.exists) return;

    final medicineData = medicineSnap.data() as Map<String, dynamic>;
    int remaining = medicineData['remainingQuantity'] ?? 0;
    int dosePerTake = medicineData['dosePerTake'] ?? 1;

    int newRemaining = remaining - dosePerTake;
    if (newRemaining < 0) newRemaining = 0;

    await medicineRef.update({'remainingQuantity': newRemaining});

    if (scheduleType == 'repeat') {
      if (newRemaining > 0) {
        int repeatHours = data['repeatHours'] ?? 4;

        Timestamp? prevTimestamp = data['scheduledTime'];
        DateTime baseTime = prevTimestamp != null ? prevTimestamp.toDate() : DateTime.now();
        DateTime nextTime = baseTime.add(Duration(hours: repeatHours));

        String dateKey =
            '${nextTime.year}-${nextTime.month.toString().padLeft(2, '0')}-${nextTime.day.toString().padLeft(2, '0')}';
        String timeLabel =
            '${nextTime.hour.toString().padLeft(2, '0')}:${nextTime.minute.toString().padLeft(2, '0')}';

        await FirebaseFirestore.instance.collection('reminders').add({
          'elderlyId': data['elderlyId'],
          'medicineId': medicineId,
          'name': data['name'],
          'time': 'ทุก $repeatHours ชั่วโมง ($timeLabel)',
          'scheduleType': 'repeat',
          'repeatHours': repeatHours,
          'scheduledTime': Timestamp.fromDate(nextTime),
          'dateKey': dateKey,
          'isDone': false,
          'isOverdue': false,
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${data['name']} ยาหมดแล้ว')),
          );
        }
      }
    }
  }

  void _deleteReminder(String docId) {
    FirebaseFirestore.instance.collection('reminders').doc(docId).update({'hidden': true});
  }

  List<_ReminderItem> _buildItems(List<QueryDocumentSnapshot> docs) {
    DateTime now = DateTime.now();
    String todayKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    List<_ReminderItem> items = [];

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;

      if (data['hidden'] == true) continue;

      String name = data['name'] ?? '';
      String time = data['time'] ?? '';
      bool isDone = data['isDone'] ?? false;
      String medicineId = data['medicineId'] ?? '';

      Timestamp? scheduledTs = data['scheduledTime'];
      DateTime? scheduledTime = scheduledTs?.toDate();

      bool isOverdue = false;
      if (!isDone && scheduledTime != null) {
        isOverdue = scheduledTime.isBefore(now);
      }

      bool isFromPreviousDay = false;
      String? dateKey = data['dateKey'];
      if (!isDone && dateKey != null) {
        isFromPreviousDay = dateKey != todayKey;
      }

      int rank;
      if (isDone) {
        rank = 3;
      } else if (isOverdue) {
        rank = 0;
      } else if (scheduledTime != null) {
        rank = 1;
      } else {
        rank = 2;
      }

      items.add(_ReminderItem(
        doc: doc,
        data: data,
        name: name,
        time: time,
        isDone: isDone,
        isOverdue: isOverdue,
        isFromPreviousDay: isFromPreviousDay,
        medicineId: medicineId,
        scheduledTime: scheduledTime,
        sortRank: rank,
      ));
    }

    items.sort((a, b) {
      if (a.sortRank != b.sortRank) {
        return a.sortRank.compareTo(b.sortRank);
      }
      if (a.scheduledTime != null && b.scheduledTime != null) {
        return a.scheduledTime!.compareTo(b.scheduledTime!);
      }
      if (a.scheduledTime == null && b.scheduledTime != null) return 1;
      if (a.scheduledTime != null && b.scheduledTime == null) return -1;
      return 0;
    });

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final reminders = FirebaseFirestore.instance
        .collection('reminders')
        .where('elderlyId', isEqualTo: widget.elderlyId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('แจ้งเตือนวันนี้'),
        backgroundColor: const Color(0xFF0D3B3E),
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: reminders.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          List<_ReminderItem> items = _buildItems(docs);

          if (items.isEmpty) {
            return const Center(child: Text('ยังไม่มีรายการแจ้งเตือน'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];

              Color cardColor = Colors.white;
              if (item.isOverdue && !item.isDone) {
                cardColor = const Color(0xFFFCE7E7);
              }

              Color iconColor = const Color(0xFF0D3B3E);
              if (item.isDone) {
                iconColor = Colors.green;
              } else if (item.isOverdue) {
                iconColor = Colors.red;
              }

              Color medicineTagColor = getMedicineColor(item.medicineId);

              String statusText;
              if (item.isFromPreviousDay) {
                statusText = 'ค้างจากเมื่อวาน — ${item.time}';
              } else if (item.isOverdue) {
                statusText = 'เลยเวลา ${item.time} — โปรดยืนยัน';
              } else {
                statusText = 'เวลา ${item.time}';
              }

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: medicineTagColor, width: 8)),
                ),
                child: Card(
                  color: cardColor,
                  margin: EdgeInsets.zero,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(
                          item.isDone ? Icons.check_circle : Icons.notifications,
                          color: iconColor,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(statusText),
                            ],
                          ),
                        ),
                        if (item.isDone)
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteReminder(item.doc.id),
                          )
                        else
                          ElevatedButton(
                            onPressed: () => _confirmTaken(item.doc),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D3B3E),
                            ),
                            child: const Text('รับประทานแล้ว'),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}