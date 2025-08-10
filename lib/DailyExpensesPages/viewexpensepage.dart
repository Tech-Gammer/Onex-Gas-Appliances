// import 'package:flutter/material.dart';
// import 'package:firebase_database/firebase_database.dart';
// import 'package:intl/intl.dart';
// import 'package:provider/provider.dart';
// import '../Provider/lanprovider.dart';
// import '../dashboard.dart';
// import 'addexpensepage.dart';
// import 'package:pdf/pdf.dart';
// import 'package:pdf/widgets.dart' as pw;
// import 'package:printing/printing.dart';
// import 'dart:ui' as ui; // Keep this import only once
// import 'package:flutter/services.dart';
// import 'package:flutter/rendering.dart'; // This can be removed if not necessary
//
// class ViewExpensesPage extends StatefulWidget {
//   @override
//   _ViewExpensesPageState createState() => _ViewExpensesPageState();
// }
//
// class _ViewExpensesPageState extends State<ViewExpensesPage> {
//   final DatabaseReference dbRef = FirebaseDatabase.instance.ref("dailyKharcha");
//   List<Map<String, dynamic>> expenses = [];
//   double _originalOpeningBalance = 0.0;
//   double _totalExpense = 0.0;
//   double _remainingBalance = 0.0;
//   DateTime _selectedDate = DateTime.now(); // Default date is today
//
//   @override
//   void initState() {
//     super.initState();
//     _fetchOpeningBalance();
//     _fetchExpenses();
//   }
//
//   void _updateRemainingBalance() {
//     setState(() {
//       _remainingBalance = _originalOpeningBalance - _totalExpense;
//     });
//   }
//
//   // Fetch the original opening balance for the selected date
//   void _fetchOpeningBalance() async {
//     String formattedDate = DateFormat('dd:MM:yyyy').format(_selectedDate);
//     final snapshot = await dbRef.child("originalOpeningBalance").child(formattedDate).get();
//     if (snapshot.exists) {
//       setState(() {
//         _originalOpeningBalance = (snapshot.value as num).toDouble();
//       });
//       _updateRemainingBalance();
//     }
//   }
//
//   void _fetchExpenses() {
//     String formattedDate = DateFormat('dd:MM:yyyy').format(_selectedDate);
//     dbRef.child(formattedDate).child("expenses").onValue.listen((event) {
//       final Map data = event.snapshot.value as Map? ?? {};
//       final List<Map<String, dynamic>> loadedExpenses = [];
//       double totalExpense = 0.0;
//
//       data.forEach((key, value) {
//         loadedExpenses.add({
//           "id": key,
//           "description": value["description"] ?? "No Description",
//           "amount": (value["amount"] as num).toDouble(),
//           "date": value["date"] ?? formattedDate,
//         });
//
//         totalExpense += (value["amount"] as num).toDouble();
//       });
//
//       setState(() {
//         expenses = loadedExpenses;
//         _totalExpense = totalExpense;
//       });
//       _updateRemainingBalance();
//     });
//   }
//
//   void _pickDate() async {
//     final pickedDate = await showDatePicker(
//       context: context,
//       initialDate: _selectedDate,
//       firstDate: DateTime(2000),
//       lastDate: DateTime.now(),
//     );
//     if (pickedDate != null) {
//       setState(() {
//         _selectedDate = pickedDate;
//         _fetchOpeningBalance(); // Fetch opening balance for the new date
//         _fetchExpenses(); // Fetch expenses for the new date
//       });
//     }
//   }
//
//   Future<pw.MemoryImage> _createTextImage(String text) async {
//     // Create a custom painter with the Urdu text
//     final recorder = ui.PictureRecorder();
//     final canvas = Canvas(recorder, Rect.fromPoints(Offset(0, 0), Offset(500, 50)));
//     final paint = Paint()..color = Colors.black;
//
//     final textStyle = TextStyle(fontSize: 16, fontFamily: 'JameelNoori', color: Colors.black, fontWeight: FontWeight.bold);
//     final textSpan = TextSpan(text: text, style: textStyle);
//
//     // Explicitly pass a nullable TextDirection
//     final textPainter = TextPainter(
//       text: textSpan,
//       textAlign: TextAlign.left,
//       // textDirection: TextDirection.ltr, // Correct enum value usage
//       textDirection: ui.TextDirection.ltr
//     );
//
//
//     textPainter.layout();
//     textPainter.paint(canvas, Offset(0, 0));
//
//     // Create image from the canvas
//     final picture = recorder.endRecording();
//     final img = await picture.toImage(textPainter.width.toInt(), textPainter.height.toInt());
//     final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
//     final buffer = byteData!.buffer.asUint8List();
//
//     return pw.MemoryImage(buffer);  // Return the image as MemoryImage
//   }
//
//   void _generatePdf() async {
//     final pdf = pw.Document();
//
//     // Load the footer logo
//     final ByteData footerBytes = await rootBundle.load('assets/images/devlogo.png');
//     final footerBuffer = footerBytes.buffer.asUint8List();
//     final footerLogo = pw.MemoryImage(footerBuffer);
//
//     // Load the image asset for the logo
//     final ByteData bytes = await rootBundle.load('assets/images/logo.png');
//     final buffer = bytes.buffer.asUint8List();
//     final image = pw.MemoryImage(buffer);
//
//     // Pre-generate images for descriptions
//     List<pw.MemoryImage> descriptionImages = [];
//     for (var expense in expenses) {
//       final image = await _createTextImage(expense['description']);
//       descriptionImages.add(image);
//     }
//
//     pdf.addPage(
//       pw.MultiPage(
//         pageFormat: PdfPageFormat.a4,
//         margin: const pw.EdgeInsets.all(20),
//
//         // Header
//         header: (pw.Context context) => pw.Row(
//           mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//           children: [
//             pw.Column(
//               crossAxisAlignment: pw.CrossAxisAlignment.start,
//               children: [
//                 pw.Text(
//                   'Daily Expense Report',
//                   style: pw.TextStyle(
//                     fontSize: 28,
//                     fontWeight: pw.FontWeight.bold,
//                     color: PdfColor.fromInt(0xFF00695C),
//                   ),
//                 ),
//                 pw.SizedBox(height: 10),
//                 pw.Text(
//                   'Opening Balance: ${_originalOpeningBalance.toStringAsFixed(2)} rs',
//                   style: pw.TextStyle(fontSize: 20),
//                 ),
//                 pw.Text(
//                   'Selected Date: ${DateFormat('dd:MM:yyyy').format(_selectedDate)}',
//                   style: pw.TextStyle(fontSize: 20),
//                 ),
//                 pw.SizedBox(height: 15),
//                 pw.Text(
//                   'Expenses',
//                   style: pw.TextStyle(
//                     fontSize: 24,
//                     fontWeight: pw.FontWeight.bold,
//                   ),
//                 ),
//                 pw.SizedBox(height: 10),
//               ]
//             ),
//             pw.Image(image, width: 100, height: 100,dpi: 1000), // Adjust logo size
//           ],
//         ),
//
//         // Body (Expense List)
//         build: (pw.Context context) => [
//           pw.TableHelper.fromTextArray(
//             headers: ['Description', 'Amount (rs)', 'Date'],
//             data: List.generate(
//               expenses.length,
//                   (index) {
//                 final expense = expenses[index];
//                 return [
//                   pw.Image(descriptionImages[index], dpi: 300),
//                   "${expense["amount"].toStringAsFixed(2)} rs",
//                   expense["date"],
//                 ];
//               },
//             ),
//             border: pw.TableBorder.all(),
//             cellAlignment: pw.Alignment.centerLeft,
//             headerStyle: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
//             cellStyle: pw.TextStyle(fontSize: 16),
//           ),
//         ],
//
//         // Footer
//         footer: (pw.Context context) => pw.Column(
//           children: [
//             pw.SizedBox(height: 10),
//             pw.Divider(),
//             pw.Text(
//               'Total Expenses: ${_totalExpense.toStringAsFixed(2)} rs',
//               style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
//             ),
//             pw.Text(
//               'Remaining Balance: ${_remainingBalance.toStringAsFixed(2)} rs',
//               style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
//             ),
//             pw.SizedBox(height: 15),
//             pw.Divider(),
//             pw.Row(
//               mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//               children: [
//                 pw.Image(footerLogo, width: 30, height: 30, dpi: 300),
//                 pw.Column(
//                   crossAxisAlignment: pw.CrossAxisAlignment.center,
//                   children: [
//                     pw.Text(
//                       'Developed By: Umair Arshad',
//                       style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
//                     ),
//                     pw.Text(
//                       'Contact: 0307-6455926',
//                       style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
//                     ),
//                   ],//s
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//
//     // Save the PDF to a file or print it
//     await Printing.layoutPdf(
//       onLayout: (PdfPageFormat format) async => pdf.save(),
//     );
//   }
//
//   Widget _buildTotalItem({required String label, required String value}) {
//     return Column(
//       children: [
//         Text(
//           label,
//           style: TextStyle(
//             fontSize: 16,
//             color: Colors.teal.shade700,
//           ),
//         ),
//         const SizedBox(height: 4),
//         Text(
//           "$value rs",
//           style: TextStyle(
//             fontSize: 18,
//             fontWeight: FontWeight.bold,
//             color: Colors.teal.shade700,
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildTotalSection(LanguageProvider languageProvider) {
//     return Card(
//       elevation: 4,
//       margin: const EdgeInsets.symmetric(vertical: 8),
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.spaceAround,
//           children: [
//             _buildTotalItem(
//               label: languageProvider.isEnglish ? 'Total Expenses' : 'کل اخراجات',
//               value: _totalExpense.toStringAsFixed(2),
//             ),
//             _buildTotalItem(
//               label: languageProvider.isEnglish ? 'Remaining Balance' : 'بقایا رقم',
//               value: _remainingBalance.toStringAsFixed(2),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   void _confirmDeleteExpense(Map<String, dynamic> expense, BuildContext context) async {
//     final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
//
//     final confirmDelete = await showDialog<bool>(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text(languageProvider.isEnglish ? 'Delete Expense?' : 'اخراجات کو حذف کریں؟'),
//           content: Text(languageProvider.isEnglish
//               ? 'Are you sure you want to delete this expense?'
//               : 'کیا آپ واقعی یہ اخراجات حذف کرنا چاہتے ہیں؟'),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.of(context).pop(false),
//               child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں'),
//             ),
//             TextButton(
//               onPressed: () => Navigator.of(context).pop(true),
//               child: Text(languageProvider.isEnglish ? 'Delete' : 'حذف کریں'),
//             ),
//           ],
//         );
//       },
//     );
//
//     if (confirmDelete == true) {
//       try {
//         final expenseId = expense["id"];
//         String formattedDate = DateFormat('dd:MM:yyyy').format(_selectedDate);
//         await dbRef.child(formattedDate).child("expenses").child(expenseId).remove();
//         _fetchExpenses();
//
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(languageProvider.isEnglish
//                 ? 'Expense deleted successfully'
//                 : 'اخراجات کامیابی سے حذف ہو گئے'),
//           ),
//         );
//       } catch (error) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(languageProvider.isEnglish
//                 ? 'Error deleting expense: $error'
//                 : 'اخراجات کو حذف کرنے میں خرابی: $error'),
//           ),
//         );
//       }
//     }
//   }
//
//   Widget _buildMobileExpenseList() {
//     return ListView.separated(
//       itemCount: expenses.length,
//       separatorBuilder: (context, index) => Divider(height: 1),
//       itemBuilder: (ctx, index) {
//         final expense = expenses[index];
//         return ListTile(
//           contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
//           title: Text(
//             expense["description"],
//             style: TextStyle(
//               color: Colors.teal.shade800,
//               fontWeight: FontWeight.bold,
//               fontSize: 16,
//             ),
//           ),
//           subtitle: Text(
//             expense["date"],
//             style: TextStyle(color: Colors.teal.shade600),
//           ),
//           trailing: Container(
//             padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
//             decoration: BoxDecoration(
//               color: Colors.teal.shade50,
//               borderRadius: BorderRadius.circular(6),
//             ),
//             child: Text(
//               "${expense["amount"].toStringAsFixed(2)} rs",
//               style: TextStyle(
//                 color: Colors.teal.shade800,
//                 fontWeight: FontWeight.bold,
//                 fontSize: 16,
//               ),
//             ),
//           ),
//           onLongPress: () => _confirmDeleteExpense(expense, context),
//         );
//       },
//     );
//   }
//
//   Widget _buildWideExpenseList() {
//     return SingleChildScrollView(
//       scrollDirection: Axis.vertical,
//       child: DataTable(
//         columnSpacing: 20,
//         horizontalMargin: 16,
//         columns: [
//           DataColumn(label: Text('Description')),
//           DataColumn(label: Text('Date'), numeric: false),
//           DataColumn(label: Text('Amount'), numeric: true),
//         ],
//         rows: expenses.map((expense) {
//           return DataRow(
//             cells: [
//               DataCell(Text(expense["description"])),
//               DataCell(Text(expense["date"])),
//               DataCell(
//                 Container(
//                   padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
//                   decoration: BoxDecoration(
//                     color: Colors.teal.shade50,
//                     borderRadius: BorderRadius.circular(6),
//                   ),
//                   child: Text(
//                     "${expense["amount"].toStringAsFixed(2)} rs",
//                     style: TextStyle(
//                       color: Colors.teal.shade800,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//             onLongPress: () => _confirmDeleteExpense(expense, context),
//           );
//         }).toList(),
//       ),
//     );
//   }
//
//   Widget _buildExpenseList(LanguageProvider languageProvider) {
//     return Expanded(
//       child: Card(
//         elevation: 4,
//         margin: const EdgeInsets.symmetric(vertical: 8),
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(12),
//         ),
//         child: Padding(
//           padding: const EdgeInsets.all(8.0),
//           child: expenses.isEmpty
//               ? Center(
//             child: Padding(
//               padding: const EdgeInsets.all(20.0),
//               child: Text(
//                 languageProvider.isEnglish
//                     ? 'No expenses found for this date'
//                     : 'اس تاریخ کے لیے کوئی اخراجات نہیں ملے',
//                 style: TextStyle(
//                   color: Colors.teal.shade700,
//                   fontSize: 18,
//                 ),
//                 textAlign: TextAlign.center,
//               ),
//             ),
//           )
//               : LayoutBuilder(
//             builder: (context, constraints) {
//               if (constraints.maxWidth > 600) {
//                 return _buildWideExpenseList();
//               }
//               return _buildMobileExpenseList();
//             },
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildDatePicker(LanguageProvider languageProvider) {
//     return ElevatedButton.icon(
//       icon: Icon(Icons.calendar_today, size: 20, color: Colors.white),
//       label: Text(
//         languageProvider.isEnglish ? 'Change Date' : 'تاریخ تبدیل کریں',
//         style: TextStyle(color: Colors.white),
//       ),
//       style: ElevatedButton.styleFrom(
//         padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
//         backgroundColor: Colors.teal.shade400,
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(8),
//         ),
//       ),
//       onPressed: _pickDate, // Moved onPressed to proper location
//     );
//   }
//
//   Widget _buildBalanceInfo(LanguageProvider languageProvider) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           languageProvider.isEnglish
//               ? 'Opening Balance: ${_originalOpeningBalance.toStringAsFixed(2)} rs'
//               : ' اوپننگ بیلنس: ${_originalOpeningBalance.toStringAsFixed(2)} روپے',
//           style: TextStyle(
//             fontSize: 18,
//             fontWeight: FontWeight.bold,
//             color: Colors.teal.shade700,
//           ),
//         ),
//         const SizedBox(height: 8),
//         Text(
//           '${languageProvider.isEnglish ? 'Selected Date:' : 'تاریخ منتخب کریں:'} ${DateFormat('dd:MM:yyyy').format(_selectedDate)}',
//           style: TextStyle(
//             fontSize: 16,
//             color: Colors.teal.shade700,
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildHeader(LanguageProvider languageProvider) {
//     return Card(
//       elevation: 4,
//       margin: const EdgeInsets.symmetric(vertical: 8),
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             LayoutBuilder(
//               builder: (context, constraints) {
//                 if (constraints.maxWidth > 600) {
//                   return Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       _buildBalanceInfo(languageProvider),
//                       _buildDatePicker(languageProvider),
//                     ],
//                   );
//                 } else {
//                   return Column(
//                     children: [
//                       _buildBalanceInfo(languageProvider),
//                       const SizedBox(height: 16),
//                       _buildDatePicker(languageProvider),
//                     ],
//                   );
//                 }
//               },
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final languageProvider = Provider.of<LanguageProvider>(context);
//
//     return Scaffold(
//       appBar: AppBar(
//           leading: IconButton(onPressed: (){
//             Navigator.pushAndRemoveUntil(
//               context,
//               MaterialPageRoute(builder: (context) => Dashboard()), // Replace HomePage with your target screen
//                   (Route<dynamic> route) => false,
//             );
//           }, icon: const Icon(Icons.arrow_back)),
//           title: Text(
//             languageProvider.isEnglish ? 'View Daily Expense' : 'روزانہ کے اخراجات',
//             style: TextStyle(color: Colors.white),
//           ),
//           backgroundColor: Colors.teal,
//           centerTitle: true,
//           actions: [
//           IconButton(
//           icon: const Icon(Icons.add, color: Colors.white),
//           onPressed: () => Navigator.push(
//             context,
//             MaterialPageRoute(builder: (context) => AddExpensePage()),),),
//           IconButton(
//               icon: const Icon(Icons.print, color: Colors.white),
//               onPressed: _generatePdf,
//             ),
//           ]
//     ),
//     body: Container(
//     constraints: BoxConstraints(maxWidth: 1200),
//     padding: EdgeInsets.all(16),
//     child: Column(
//     children: [
//     _buildHeader(languageProvider),
//     const SizedBox(height: 16),
//     _buildExpenseList(languageProvider),
//     const SizedBox(height: 16),
//     _buildTotalSection(languageProvider),
//     ],
//     ),
//     ),
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../Provider/lanprovider.dart';
import '../dashboard.dart';
import 'addexpensepage.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';

class ViewExpensesPage extends StatefulWidget {
  @override
  _ViewExpensesPageState createState() => _ViewExpensesPageState();
}

class _ViewExpensesPageState extends State<ViewExpensesPage> with TickerProviderStateMixin {
  final DatabaseReference dbRef = FirebaseDatabase.instance.ref("dailyKharcha");
  List<Map<String, dynamic>> expenses = [];
  double _originalOpeningBalance = 0.0;
  double _totalExpense = 0.0;
  double _remainingBalance = 0.0;
  DateTime _selectedDate = DateTime.now();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _fetchOpeningBalance();
    _fetchExpenses();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _updateRemainingBalance() {
    setState(() {
      _remainingBalance = _originalOpeningBalance - _totalExpense;
    });
  }

  // Fetch the original opening balance for the selected date
  void _fetchOpeningBalance() async {
    String formattedDate = DateFormat('dd:MM:yyyy').format(_selectedDate);
    final snapshot = await dbRef.child("originalOpeningBalance").child(formattedDate).get();
    if (snapshot.exists) {
      setState(() {
        _originalOpeningBalance = (snapshot.value as num).toDouble();
      });
      _updateRemainingBalance();
    }
  }

  void _fetchExpenses() {
    String formattedDate = DateFormat('dd:MM:yyyy').format(_selectedDate);
    dbRef.child(formattedDate).child("expenses").onValue.listen((event) {
      final Map data = event.snapshot.value as Map? ?? {};
      final List<Map<String, dynamic>> loadedExpenses = [];
      double totalExpense = 0.0;

      data.forEach((key, value) {
        loadedExpenses.add({
          "id": key,
          "description": value["description"] ?? "No Description",
          "amount": (value["amount"] as num).toDouble(),
          "date": value["date"] ?? formattedDate,
        });

        totalExpense += (value["amount"] as num).toDouble();
      });

      setState(() {
        expenses = loadedExpenses;
        _totalExpense = totalExpense;
      });
      _updateRemainingBalance();
    });
  }

  void _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF6C63FF),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
        _fetchOpeningBalance();
        _fetchExpenses();
      });
    }
  }

  Future<pw.MemoryImage> _createTextImage(String text) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromPoints(Offset(0, 0), Offset(500, 50)));
    final paint = Paint()..color = Colors.black;

    final textStyle = TextStyle(fontSize: 16, fontFamily: 'JameelNoori', color: Colors.black, fontWeight: FontWeight.bold);
    final textSpan = TextSpan(text: text, style: textStyle);

    final textPainter = TextPainter(
        text: textSpan,
        textAlign: TextAlign.left,
        textDirection: ui.TextDirection.ltr
    );

    textPainter.layout();
    textPainter.paint(canvas, Offset(0, 0));

    final picture = recorder.endRecording();
    final img = await picture.toImage(textPainter.width.toInt(), textPainter.height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();

    return pw.MemoryImage(buffer);
  }

  void _generatePdf() async {
    final pdf = pw.Document();

    final ByteData footerBytes = await rootBundle.load('assets/images/devlogo.png');
    final footerBuffer = footerBytes.buffer.asUint8List();
    final footerLogo = pw.MemoryImage(footerBuffer);

    final ByteData bytes = await rootBundle.load('assets/images/logo.png');
    final buffer = bytes.buffer.asUint8List();
    final image = pw.MemoryImage(buffer);

    List<pw.MemoryImage> descriptionImages = [];
    for (var expense in expenses) {
      final image = await _createTextImage(expense['description']);
      descriptionImages.add(image);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        header: (pw.Context context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Daily Expense Report',
                    style: pw.TextStyle(
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(0xFF00695C),
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'Opening Balance: ${_originalOpeningBalance.toStringAsFixed(2)} rs',
                    style: pw.TextStyle(fontSize: 20),
                  ),
                  pw.Text(
                    'Selected Date: ${DateFormat('dd:MM:yyyy').format(_selectedDate)}',
                    style: pw.TextStyle(fontSize: 20),
                  ),
                  pw.SizedBox(height: 15),
                  pw.Text(
                    'Expenses',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                ]
            ),
            pw.Image(image, width: 100, height: 100,dpi: 1000),
          ],
        ),
        build: (pw.Context context) => [
          pw.TableHelper.fromTextArray(
            headers: ['Description', 'Amount (rs)', 'Date'],
            data: List.generate(
              expenses.length,
                  (index) {
                final expense = expenses[index];
                return [
                  pw.Image(descriptionImages[index], dpi: 300),
                  "${expense["amount"].toStringAsFixed(2)} rs",
                  expense["date"],
                ];
              },
            ),
            border: pw.TableBorder.all(),
            cellAlignment: pw.Alignment.centerLeft,
            headerStyle: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            cellStyle: pw.TextStyle(fontSize: 16),
          ),
        ],
        footer: (pw.Context context) => pw.Column(
          children: [
            pw.SizedBox(height: 10),
            pw.Divider(),
            pw.Text(
              'Total Expenses: ${_totalExpense.toStringAsFixed(2)} rs',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'Remaining Balance: ${_remainingBalance.toStringAsFixed(2)} rs',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 15),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Image(footerLogo, width: 30, height: 30, dpi: 300),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'Developed By: Umair Arshad',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      'Contact: 0307-6455926',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  void _confirmDeleteExpense(Map<String, dynamic> expense, BuildContext context) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    final confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            languageProvider.isEnglish ? 'Delete Expense?' : 'اخراجات کو حذف کریں؟',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF6C63FF),
            ),
          ),
          content: Text(languageProvider.isEnglish
              ? 'Are you sure you want to delete this expense?'
              : 'کیا آپ واقعی یہ اخراجات حذف کرنا چاہتے ہیں؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
              ),
              child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[400],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(languageProvider.isEnglish ? 'Delete' : 'حذف کریں'),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      try {
        final expenseId = expense["id"];
        String formattedDate = DateFormat('dd:MM:yyyy').format(_selectedDate);
        await dbRef.child(formattedDate).child("expenses").child(expenseId).remove();
        _fetchExpenses();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(languageProvider.isEnglish
                ? 'Expense deleted successfully'
                : 'اخراجات کامیابی سے حذف ہو گئے'),
            backgroundColor: Colors.green,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(languageProvider.isEnglish
                ? 'Error deleting expense: $error'
                : 'اخراجات کو حذف کرنے میں خرابی: $error'),
            backgroundColor: Colors.red,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildModernHeader(LanguageProvider languageProvider) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF9C63FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF6C63FF).withOpacity(0.3),
            blurRadius: 15,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                padding: EdgeInsets.all(12),
                child: Icon(
                  Icons.account_balance_wallet,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      languageProvider.isEnglish ? 'Opening Balance' : 'اوپننگ بیلنس',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${_originalOpeningBalance.toStringAsFixed(2)} rs',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(15),
            ),
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      languageProvider.isEnglish ? 'Selected Date' : 'منتخب کردہ تاریخ',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      DateFormat('dd MMM yyyy').format(_selectedDate),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.all(10),
                    child: Icon(
                      Icons.calendar_today,
                      color: Color(0xFF6C63FF),
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(LanguageProvider languageProvider) {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  padding: EdgeInsets.all(12),
                  child: Icon(
                    Icons.trending_down,
                    color: Colors.red,
                    size: 24,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  languageProvider.isEnglish ? 'Total Expenses' : 'کل اخراجات',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '${_totalExpense.toStringAsFixed(2)} rs',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  padding: EdgeInsets.all(12),
                  child: Icon(
                    Icons.trending_up,
                    color: Colors.green,
                    size: 24,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  languageProvider.isEnglish ? 'Remaining' : 'باقی رقم',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '${_remainingBalance.toStringAsFixed(2)} rs',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernExpenseItem(Map<String, dynamic> expense, int index) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onLongPress: () => _confirmDeleteExpense(expense, context),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF6C63FF).withOpacity(0.8),
                        Color(0xFF9C63FF).withOpacity(0.8),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  padding: EdgeInsets.all(12),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense["description"],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        expense["date"],
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  child: Text(
                    "${expense["amount"].toStringAsFixed(2)} rs",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6C63FF),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpensesList(LanguageProvider languageProvider) {
    if (expenses.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        padding: EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              languageProvider.isEnglish
                  ? 'No expenses found for this date'
                  : 'اس تاریخ کے لیے کوئی اخراجات نہیں ملے',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          child: Text(
            languageProvider.isEnglish
                ? 'Expense Details (${expenses.length} items)'
                : 'اخراجات کی تفصیلات (${expenses.length} اشیاء)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
        ),
        ...expenses.asMap().entries.map((entry) {
          return _buildModernExpenseItem(entry.value, entry.key);
        }).toList(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: Color(0xFFF8F9FF),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => Dashboard()),
                  (Route<dynamic> route) => false,
            );
          },
          icon: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            padding: EdgeInsets.all(8),
            child: Icon(
              Icons.arrow_back,
              color: Color(0xFF6C63FF),
            ),
          ),
        ),
        title: Text(
          languageProvider.isEnglish ? 'Daily Expenses' : 'روزانہ اخراجات',
          style: TextStyle(
            color: Colors.grey[800],
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(Icons.add, color: Color(0xFF6C63FF)),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddExpensePage()),
              ),
            ),
          ),
          Container(
            margin: EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(Icons.print, color: Color(0xFF6C63FF)),
              onPressed: _generatePdf,
            ),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              _buildModernHeader(languageProvider),
              SizedBox(height: 24),
              _buildStatsCards(languageProvider),
              SizedBox(height: 24),
              _buildExpensesList(languageProvider),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}