import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';

class RoznamchaPage extends StatefulWidget {
  @override
  _RoznamchaPageState createState() => _RoznamchaPageState();
}

class _RoznamchaPageState extends State<RoznamchaPage> {
  final _databaseRef = FirebaseDatabase.instance.ref("roznamcha");
  final _descController = TextEditingController();
  final _amountController = TextEditingController(); // Add this line
  DateTime _selectedDate = DateTime.now();
  File? _imageFile;


  // Pick Image Function
  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  // Upload Image to Firebase Storage
  Future<String?> _uploadImage(File imageFile) async {
    try {
      String fileName = basename(imageFile.path);
      Reference storageRef = FirebaseStorage.instance.ref().child("roznamcha/$fileName");
      await storageRef.putFile(imageFile);
      return await storageRef.getDownloadURL();
    } catch (e) {
      print("Image Upload Error: $e");
      return null;
    }
  }

  // Pick Date Function
  Future<void> _pickDate(BuildContext context) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  // Save Data to Firebase Realtime Database
  Future<void> _saveRoznamcha(BuildContext context) async {
    if (_descController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Description is required!")));
      return;
    }

    // Validate amount
    double? amount = double.tryParse(_amountController.text);
    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Enter a valid amount!")));
      return;
    }

    String? imageUrl;
    if (_imageFile != null) {
      imageUrl = await _uploadImage(_imageFile!);
    }

    String formattedDate = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";

    await _databaseRef.push().set({
      "description": _descController.text,
      "date": formattedDate,
      "imageUrl": imageUrl ?? "",
      "amount": amount, // Add amount to Firebase
    });

    // Clear fields after saving
    setState(() {
      _descController.clear();
      _amountController.clear(); // Clear amount
      _imageFile = null;
      _selectedDate = DateTime.now();
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Roznamcha entry added!")));
  }


  @override
  void dispose() {
    _descController.dispose();
    _amountController.dispose(); // Dispose the controller
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: Text("Roznamcha",style: TextStyle(color: Colors.white),),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Description Field
              TextField(
                controller: _descController,
                decoration: InputDecoration(
                  labelText: "Description",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: Icon(Icons.description, color: Colors.teal),
                ),
                maxLines: 2,
              ),
              SizedBox(height: 20),
              TextField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: "Amount",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: Icon(Icons.attach_money, color: Colors.teal),
                ),
                keyboardType: TextInputType.number,
              ),
              // Date Picker
              Row(
                children: [
                  Icon(Icons.calendar_today, color: Colors.teal),
                  SizedBox(width: 10),
                  Text(
                    "Date: ${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}",
                    style: TextStyle(fontSize: 16),
                  ),
                  Spacer(),
                  ElevatedButton(
                    onPressed: () => _pickDate(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text("Select Date",style: TextStyle(color: Colors.white),),
                  ),
                ],
              ),
              SizedBox(height: 20),

              // Image Picker and Display
              _imageFile != null
                  ? Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Container(
                  width: isMobile ? double.infinity : 300,
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    image: DecorationImage(
                      image: FileImage(_imageFile!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              )
                  : Text(
                "No Image Selected",
                style: TextStyle(color: Colors.grey),
              ),
              SizedBox(height: 20),

              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: _pickImage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.image),
                        SizedBox(width: 5),
                        Text("Pick Image",style: TextStyle(color: Colors.white),),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _saveRoznamcha(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.save),
                        SizedBox(width: 5),
                        Text("Save Entry",style: TextStyle(color: Colors.white),),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}