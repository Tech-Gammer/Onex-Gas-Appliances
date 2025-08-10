import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Provider/lanprovider.dart';

class AddVendorPage extends StatefulWidget {
  const AddVendorPage({super.key});

  @override
  State<AddVendorPage> createState() => _AddVendorPageState();
}

class _AddVendorPageState extends State<AddVendorPage> {
  final TextEditingController _vendorNameController = TextEditingController();
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref("vendors");

  void _addVendor() async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final vendorName = _vendorNameController.text.trim();
    if (vendorName.isNotEmpty) {
      try {
        await _databaseRef.push().set({"name": vendorName});
        _vendorNameController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content:Text(languageProvider.isEnglish
              ? 'Vendor added successfully!'
              : 'وینڈر کامیابی سے شامل کر دیا گیا!'),),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(languageProvider.isEnglish
              ? 'Error adding vendor: $e'
              : 'وینڈر شامل کرنے میں خرابی: $e'),),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(languageProvider.isEnglish
            ? 'Vendor name cannot be empty.'
            : 'وینڈر کا نام خالی نہیں ہو سکتا۔'),),
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title:  Text(
          languageProvider.isEnglish ? 'Add Vendor' : 'وینڈر شامل کریں',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF8A65), Color(0xFFFFB74D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Text(
              languageProvider.isEnglish ? 'Enter Vendor Name' : 'وینڈر کا نام درج کریں',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _vendorNameController,
              decoration:  InputDecoration(
                border: OutlineInputBorder(),
                hintText: languageProvider.isEnglish ? 'Vendor Name' : 'وینڈر کا نام',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _addVendor,
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white, backgroundColor: Colors.orange[300], // Text color
                padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 24.0), // Padding
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0), // Rounded corners
                ),
                elevation: 5, // Shadow effect
              ),
              child: Text(languageProvider.isEnglish ? 'Add Vendor' : 'وینڈر شامل کریں'),
            ),

          ],
        ),
      ),
    );
  }
}
