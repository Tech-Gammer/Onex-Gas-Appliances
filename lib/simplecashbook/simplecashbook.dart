import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

import '../Provider/lanprovider.dart';
import 'package:provider/provider.dart';

import 'simplecashbookform.dart';
import 'simplecashbooklist.dart';

class SimpleCashbookPage extends StatefulWidget {
  @override
  _SimpleCashbookPageState createState() => _SimpleCashbookPageState();
}

class _SimpleCashbookPageState extends State<SimpleCashbookPage> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref().child('simplecashbook');
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
            languageProvider.isEnglish ? 'Simple CashBook' : 'سمپل کیش بک',
            style: const TextStyle(color: Colors.white)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF8A65), Color(0xFFFFB74D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SimpleCashbookFormPage(
                        databaseRef: _databaseRef,
                      ),
                    ),
                  );
                },
                child: Text(
                  languageProvider.isEnglish ? 'Add New Entry' : 'نیا اندراج شامل کریں',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[300],
                ),
              ),
              const SizedBox(height: 20),
              SimpleCashbookListPage(
                databaseRef: _databaseRef,
                startDate: _startDate,
                endDate: _endDate,
                onDateRangeChanged: (start, end) {
                  setState(() {
                    _startDate = start;
                    _endDate = end;
                  });
                },
                onClearDateFilter: () {
                  setState(() {
                    _startDate = null;
                    _endDate = null;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}