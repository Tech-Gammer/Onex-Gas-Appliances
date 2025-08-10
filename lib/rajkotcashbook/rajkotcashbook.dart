import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

import '../Provider/lanprovider.dart';
import 'package:provider/provider.dart';

import 'rajkotcashbookform.dart';
import 'rajkotcashbooklist.dart';

class RajkotCashbookPage extends StatefulWidget {
  @override
  _RajkotCashbookPageState createState() => _RajkotCashbookPageState();
}

class _RajkotCashbookPageState extends State<RajkotCashbookPage> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref().child('rajkotcashbook');
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
            languageProvider.isEnglish ? 'Rajkot CashBook' : 'راجکوٹ کیش بک',
            style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.blueAccent,
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
                      builder: (context) => RajkotCashbookFormPage(
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
                  backgroundColor: Colors.blueAccent,
                ),
              ),
              const SizedBox(height: 20),
              RajkotCashbookListPage(
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