import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:onex_gas_appliances/dailypage/roznamchapage.dart';
import 'package:path/path.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;

class RoznamchaListPage extends StatefulWidget {
  @override
  _RoznamchaListPageState createState() => _RoznamchaListPageState();
}

class _RoznamchaListPageState extends State<RoznamchaListPage> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref("roznamcha");
  DateTime? _startDate;
  DateTime? _endDate;
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  List<MapEntry<dynamic, dynamic>> _filterEntries(Map<dynamic, dynamic> entries) {
    return entries.entries.where((entry) {
      final entryDate = _dateFormat.parse(entry.value['date']);
      return (_startDate == null || entryDate.isAfter(_startDate!.subtract(const Duration(days: 1)))) &&
          (_endDate == null || entryDate.isBefore(_endDate!.add(const Duration(days: 1))));
    }).toList();
  }


// Add this new function to convert text to image
  Future<pw.MemoryImage> _createTextImage(String text) async {
    // Use default text for empty input
    final String displayText = text.isEmpty ? "N/A" : text;

    // Scale factor to increase resolution
    const double scaleFactor = 1.5;

    // Create a custom painter with the Urdu text
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromPoints(
        const Offset(0, 0),
        const Offset(500 * scaleFactor, 50 * scaleFactor),
      ),
    );

    // Define text style with scaling
    final textStyle = const TextStyle(
      fontSize: 12 * scaleFactor,
      fontFamily: 'JameelNoori', // Ensure this font is registered
      color: Colors.black,
      fontWeight: FontWeight.bold,
    );

    // Create the text span and text painter
    final textSpan = TextSpan(text: displayText, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.left, // Adjust as needed for alignment
      textDirection: ui.TextDirection.rtl, // Use RTL for Urdu text
    );

    // Layout the text painter
    textPainter.layout();

    // Validate dimensions
    final double width = textPainter.width * scaleFactor;
    final double height = textPainter.height * scaleFactor;

    if (width <= 0 || height <= 0) {
      throw Exception("Invalid text dimensions: width=$width, height=$height");
    }

    // Paint the text onto the canvas
    textPainter.paint(canvas, const Offset(0, 0));

    // Create an image from the canvas
    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());

    // Convert the image to PNG
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();

    // Return the image as a MemoryImage
    return pw.MemoryImage(buffer);
  }


  // Modified PDF generation function with textToImage integration
  Future<void> _generatePdf(List<MapEntry<dynamic, dynamic>> filteredEntries) async {
    final pdf = pw.Document();
    final logo = pw.MemoryImage(
      (await rootBundle.load('assets/images/logo.png')).buffer.asUint8List(),
    );
    final footerLogo = pw.MemoryImage(
      (await rootBundle.load('assets/images/devlogo.png')).buffer.asUint8List(),
    );

    // Generate the list of table rows asynchronously
    List<pw.TableRow> tableRows = await Future.wait(
      filteredEntries.map((entry) async => pw.TableRow(
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(entry.value['date']),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Image(await _createTextImage(entry.value['description'])), // Use _createTextImage
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(entry.value['amount'].toString()),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              entry.value['imageUrl']?.isNotEmpty == true ? 'Yes' : 'No',
            ),
          ),
        ],
      )),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => pw.Container(
          alignment: pw.Alignment.center,
          child: pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Image(logo, width: 200, height: 130),
              pw.SizedBox(height: 20),
            ],
          ),
        ),
        footer: (pw.Context context) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 4),
          child: pw.Column(
            children: [
              pw.Divider(thickness: 1, color: PdfColors.grey),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Image(footerLogo, width: 30, height: 30),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text('Dev Valley Software House',
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Contact: 0303-4889663',
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Roznamcha Report ${_startDate != null ? DateFormat('yyyy-MM-dd').format(_startDate!) : ''} '
                  'to ${_endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : ''}',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Table(
            border: pw.TableBorder.all(),
            children: [
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('Image', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                ],
              ),
              ...tableRows, // Now using the awaited list of TableRow objects
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: Text("Roznamcha Entries",style: TextStyle(color: Colors.white,fontWeight: FontWeight.bold),),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: Icon(Icons.date_range, color: Colors.white),
            onPressed: () => _selectDateRange(context),
          ),
          // In the PDF button's onPressed handler:
          IconButton(
            icon: Icon(Icons.picture_as_pdf, color: Colors.white),
            onPressed: () async {
              if (_startDate == null || _endDate == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Please select a date range first")),
                );
                return;
              }

              // Get fresh data from Firebase
              final snapshot = await _databaseRef.get();
              if (!snapshot.exists) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("No data available")),
                );
                return;
              }

              final entries = snapshot.value as Map<dynamic, dynamic>;
              List<MapEntry<dynamic, dynamic>> filteredEntries = _filterEntries(entries);
              _generatePdf(filteredEntries);
            },
          ),

          IconButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => RoznamchaPage()));
            },
            icon: Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
      body: StreamBuilder(
        stream: _databaseRef.onValue,
        builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
          if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
            return Center(
              child: Text(
                "No entries found",
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          Map<dynamic, dynamic> entries = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
          List keys = entries.keys.toList();

          return Column(
            children: [
              if (_startDate != null && _endDate != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Showing entries from ${_dateFormat.format(_startDate!)} to ${_dateFormat.format(_endDate!)}',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
          Expanded(
            child: ListView.builder(
              itemCount: keys.length,
              itemBuilder: (context, index) {
                String key = keys[index];
                 Map entry = entries[key];
                 return Card(
                  margin: EdgeInsets.symmetric(vertical: 8, horizontal: isMobile ? 16 : 24),
                   elevation: 4,
                   shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    ),
                 child: ListTile(
                leading: entry["imageUrl"] != null && entry["imageUrl"].isNotEmpty
                ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                entry["imageUrl"],
                 width: 50,
                  height: 50,
                   fit: BoxFit.cover,
                  ),
                )
              : Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
              title: Text(
                entry["description"],
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  Text("Date: ${entry["date"]}", style: TextStyle(color: Colors.grey)),
                  Text("Amount: ${entry["amount"]}", style: TextStyle(color: Colors.grey)),
                  ],
               ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, color: Colors.teal),
                        onPressed: () => _editEntry(context, key, entry),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteEntry(key, context),
                      ),
                  ],
                ),
                ),
              );
            },
            ),
              )
            ],
          );
        },
      ),
    );
  }

  // Function to Delete Entry
  void _deleteEntry(String key, BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Delete Entry"),
          content: Text("Are you sure you want to delete this entry?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: TextStyle(color: Colors.teal)),
            ),
            ElevatedButton(
              onPressed: () {
                _databaseRef.child(key).remove();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Entry deleted")));
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text("Delete"),
            ),
          ],
        );
      },
    );
  }

  // Function to Edit Entry
  void _editEntry(BuildContext context, String key, Map entry) {
    TextEditingController _descController = TextEditingController(text: entry["description"]);
    TextEditingController _amountController = TextEditingController(text: entry["amount"]?.toString() ?? ''); // Add this

    DateTime _selectedDate;
    String dateStr = entry["date"];
    List<String> parts = dateStr.split('-');
    if (parts.length == 3) {
      int year = int.parse(parts[0]);
      int month = int.parse(parts[1]);
      int day = int.parse(parts[2]);
      _selectedDate = DateTime(year, month, day);
    } else {
      _selectedDate = DateTime.now(); // Default to current date if parsing fails
    }

    File? _imageFile;

    Future<void> _pickDate() async {
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

    Future<void> _pickImage() async {
      final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    }

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

    void _updateEntry() async {

      // Validate amount
      double? amount = double.tryParse(_amountController.text);
      if (amount == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Invalid amount!")));
        return;
      }

      String? imageUrl = entry["imageUrl"];
      if (_imageFile != null) {
        imageUrl = await _uploadImage(_imageFile!);
      }

      await _databaseRef.child(key).update({
        "description": _descController.text,
        "date": "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}",
        "imageUrl": imageUrl ?? "",
        "amount": amount, // Update amount
      });

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Entry updated")));
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Edit Entry"),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: _descController,
                  decoration: InputDecoration(
                    labelText: "Description",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: Icon(Icons.description, color: Colors.teal),
                  ),
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
                Row(
                  children: [
                    Icon(Icons.calendar_today, color: Colors.teal),
                    SizedBox(width: 10),
                    Text(
                      "Date: ${_selectedDate.toLocal()}".split(' ')[0],
                      style: TextStyle(fontSize: 16),
                    ),
                    Spacer(),
                    ElevatedButton(
                      onPressed: _pickDate,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                      child: Text("Select Date"),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                _imageFile != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(_imageFile!, height: 100, fit: BoxFit.cover),
                )
                    : entry["imageUrl"] != null && entry["imageUrl"].isNotEmpty
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(entry["imageUrl"], height: 100, fit: BoxFit.cover),
                )
                    : Text("No Image Selected", style: TextStyle(color: Colors.grey)),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _pickImage,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.image),
                      SizedBox(width: 5),
                      Text("Pick Image"),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: TextStyle(color: Colors.teal)),
            ),
            ElevatedButton(
              onPressed: _updateEntry,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              child: Text("Update"),
            ),
          ],
        );
      },
    );
  }
}