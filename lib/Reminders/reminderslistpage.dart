import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:onex_gas_appliances/Reminders/reminders.dart';

class ReminderListPage extends StatefulWidget {
  const ReminderListPage({super.key});

  @override
  State<ReminderListPage> createState() => _ReminderListPageState();
}

class _ReminderListPageState extends State<ReminderListPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child('reminders');
  List<Map<String, dynamic>> reminders = [];

  @override
  void initState() {
    super.initState();
    _fetchReminders();
  }

  void _fetchReminders() async {
    final snapshot = await _dbRef.get();
    if (snapshot.exists) {
      Map data = snapshot.value as Map;
      List<Map<String, dynamic>> temp = [];
      data.forEach((key, value) {
        temp.add({
          'id': key,
          'title': value['title'],
          'date': DateTime.parse(value['date']),
          'showAlert': value['showAlert'] ?? true,
        });
      });

      temp.sort((a, b) => a['date'].compareTo(b['date']));
      setState(() {
        reminders = temp;
      });
    }
  }

  void _deleteReminder(String id) {
    _dbRef.child(id).remove();
    setState(() {
      reminders.removeWhere((element) => element['id'] == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Reminders"),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF8A65), Color(0xFFFFB74D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ReminderPage()));
            },
            icon: const Icon(Icons.add),
            tooltip: "Add Reminder",
          )
        ],
      ),
      body: reminders.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.notifications_off, size: 64, color: Colors.grey),
            SizedBox(height: 10),
            Text(
              "No reminders found.",
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      )
          : ListView.builder(
        itemCount: reminders.length,
        itemBuilder: (context, index) {
          final reminder = reminders[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
            child: Card(
              color: Colors.white,
              elevation: 4,
              shadowColor: theme.primaryColor.withOpacity(0.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and Delete
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            reminder['title'],
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          color: Colors.redAccent,
                          tooltip: 'Delete Reminder',
                          onPressed: () => _deleteReminder(reminder['id']),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Date Row
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('yyyy-MM-dd').format(reminder['date']),
                          style: const TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Switch
                    Row(
                      children: [
                        const Text(
                          "Show Alert",
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                        ),
                        const Spacer(),
                        Switch(
                          value: reminder['showAlert'] ?? true,
                          activeColor: Colors.orange[300],
                          onChanged: (value) {
                            _dbRef.child(reminder['id']).update({'showAlert': value});
                            setState(() {
                              reminder['showAlert'] = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
