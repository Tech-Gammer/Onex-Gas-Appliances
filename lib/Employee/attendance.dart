import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../Provider/employeeprovider.dart';
import '../Provider/lanprovider.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';


class AttendanceReportPage extends StatefulWidget {
  @override
  _AttendanceReportPageState createState() => _AttendanceReportPageState();
}

class _AttendanceReportPageState extends State<AttendanceReportPage>with TickerProviderStateMixin {
  String _searchName = '';
  DateTimeRange? _dateRange;
  late Animation<double> _fadeAnimation;
  late AnimationController _animationController;

  // Add these new methods:
  Future<void> _savePdf(
      List<String> filteredEmployees,
      EmployeeProvider employeeProvider,
      Map<String, Map<String, String>> employees)
  async {
    try {
      final pdfBytes = await _generatePdfBytes(filteredEmployees, employeeProvider, employees);
      final String? path = await FilePicker.platform.saveFile(
        fileName: 'attendance_report.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (path != null) {
        final file = File(path);
        await file.writeAsBytes(pdfBytes);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF saved successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving PDF: $e')),
      );
    }
  }

  Future<void> _sharePdf(
      List<String> filteredEmployees,
      EmployeeProvider employeeProvider,
      Map<String, Map<String, String>> employees)
  async {
    try {
      final pdfBytes = await _generatePdfBytes(filteredEmployees, employeeProvider, employees);
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/attendance_report.pdf');
      await file.writeAsBytes(pdfBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Attendance Report',
        subject: 'Employee Attendance Details',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing PDF: $e')),
      );
    }
  }


  // @override
  // Widget build(BuildContext context) {
  //   final employeeProvider = Provider.of<EmployeeProvider>(context);
  //   final employees = employeeProvider.employees;
  //   final languageProvider = Provider.of<LanguageProvider>(context);
  //
  //   // Filter employees by name
  //   final filteredEmployees = employees.keys.where((employeeId) {
  //     final employeeName = employees[employeeId]!['name']!.toLowerCase();
  //     return employeeName.contains(_searchName.toLowerCase());
  //   }).toList();
  //
  //   return Scaffold(
  //     appBar: AppBar(
  //       title: Text(
  //         // 'Attendance Report',
  //           languageProvider.isEnglish ? 'Attendance Report' : 'حاضری کی رپورٹ',
  //         style: const TextStyle(color: Colors.white),),
  //       backgroundColor: Colors.teal,
  //       centerTitle: true,
  //               actions: [
  //         IconButton(
  //           icon: const Icon(Icons.print,color: Colors.white,),
  //           onPressed: () => _generateAndPrintPdf(filteredEmployees, employeeProvider, employees),
  //         ),
  //         IconButton(
  //           icon: const Icon(Icons.share, color: Colors.white),
  //           onPressed: () => _sharePdf(filteredEmployees, employeeProvider, employees),
  //         ),
  //       ],
  //     ),
  //     body: Column(
  //       children: [
  //         // Filter Widgets
  //         Padding(
  //           padding: const EdgeInsets.all(8.0),
  //           child: Row(
  //             children: [
  //               Expanded(
  //                 child: TextField(
  //                   decoration:  InputDecoration(
  //                     labelText: languageProvider.isEnglish ? 'Search by Name' : 'نام سے تلاش کریں۔',
  //                     prefixIcon: Icon(Icons.search),
  //                     border: OutlineInputBorder(),
  //                   ),
  //                   onChanged: (value) {
  //                     setState(() {
  //                       _searchName = value;
  //                     });
  //                   },
  //                 ),
  //               ),
  //               const SizedBox(width: 8),
  //               ElevatedButton.icon(
  //                 onPressed: () async {
  //                   final pickedDateRange = await showDateRangePicker(
  //                     context: context,
  //                     firstDate: DateTime(2000),
  //                     // lastDate: DateTime.now(),
  //                     lastDate: DateTime(20001)
  //                   );
  //                   if (pickedDateRange != null) {
  //                     setState(() {
  //                       _dateRange = pickedDateRange;
  //                     });
  //                   }
  //                 },
  //                 icon: const Icon(Icons.date_range),
  //                 label:  Text(
  //                   // 'Select Date Range'
  //                   languageProvider.isEnglish ? 'Select Date Range' : 'تاریخ کی حد منتخب کریں۔',
  //                   ),
  //                 style: ElevatedButton.styleFrom(
  //                   foregroundColor: Colors.white,
  //                   backgroundColor: Colors.teal.shade400,
  //                   shape: RoundedRectangleBorder(
  //                     borderRadius: BorderRadius.circular(8),
  //                   ),
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
  //
  //         Expanded(
  //           child: ListView.builder(
  //             itemCount: filteredEmployees.length,
  //             itemBuilder: (context, index) {
  //               final employeeId = filteredEmployees[index];
  //
  //               return FutureBuilder<Map<String, Map<String, dynamic>>>(
  //                 future: _dateRange != null
  //                     ? employeeProvider.getAttendanceForDateRange(employeeId, _dateRange!)
  //                     : Future.value({}), // Empty map if no range is selected
  //                 builder: (context, snapshot) {
  //                   if (snapshot.connectionState == ConnectionState.waiting) {
  //                     return const CircularProgressIndicator();
  //                   } else if (snapshot.hasData) {
  //                     final attendanceData = snapshot.data!;
  //                     if (attendanceData.isEmpty) {
  //                       return ListTile(
  //                         title: Text(employees[employeeId]!['name']!),
  //                         subtitle:  Text(
  //                         // 'No attendance marked for the selected range'
  //                         languageProvider.isEnglish ? 'No attendance marked for the selected range' : 'منتخب کردہ رینج کے لیے کوئی حاضری نشان زد نہیں ہے۔',
  //                         )
  //                       );
  //                     }
  //
  //                     // Display attendance for each dates
  //                     return ExpansionTile(
  //                       title: Text(employees[employeeId]!['name']!),
  //                       children: attendanceData.entries.map((entry) {
  //                         final date = entry.key;
  //                         final attendance = entry.value;
  //
  //                         return ListTile(
  //                           title: Text('Date: $date'),
  //                           subtitle: Column(
  //                             crossAxisAlignment: CrossAxisAlignment.start,
  //                             children: [
  //                               Text('Status: ${attendance['status'] ?? 'N/A'}'),
  //                               Text('Description: ${attendance['description'] ?? 'N/A'}'),
  //                               Text('Time: ${attendance['time'] ?? 'N/A'}'),
  //                             ],
  //                           ),
  //                           trailing: IconButton(
  //                             icon: const Icon(Icons.delete, color: Colors.red),
  //                             onPressed: () async {
  //                               try {
  //                                 await employeeProvider.deleteAttendance(employeeId, date);
  //                                 ScaffoldMessenger.of(context).showSnackBar(
  //                                   SnackBar(content: Text(languageProvider.isEnglish
  //                                       ? 'Attendance deleted successfully'
  //                                       : 'حاضری کامیابی سے حذف ہو گئی')),
  //                                 );
  //                               } catch (e) {
  //                                 ScaffoldMessenger.of(context).showSnackBar(
  //                                   SnackBar(content: Text(languageProvider.isEnglish
  //                                       ? 'Error deleting attendance: $e'
  //                                       : 'حاضری حذف کرنے میں خرابی: $e')),
  //                                 );
  //                               }
  //                             },
  //                           ),
  //                         );
  //                       }).toList(),
  //                     );
  //                   } else {
  //                     return ListTile(
  //                       title: Text(employees[employeeId]!['name']!),
  //                       subtitle:  Text(
  //                           // 'Error fetching attendance'
  //                         languageProvider.isEnglish ? 'Error fetching attendance' : 'حاضری حاصل کرنے میں خرابی۔',
  //
  //                       ),
  //                     );
  //                   }
  //                 },
  //               );
  //             },
  //           ),
  //         ),
  //
  //       ],
  //     ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    final employeeProvider = Provider.of<EmployeeProvider>(context);
    final employees = employeeProvider.employees;
    final languageProvider = Provider.of<LanguageProvider>(context);

    // Filter employees by name
    final filteredEmployees = employees.keys.where((employeeId) {
      final employeeName = employees[employeeId]!['name']!.toLowerCase();
      return employeeName.contains(_searchName.toLowerCase());
    }).toList();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFB74D).withOpacity(0.2),
              Colors.white,
              Color(0xFFFF8A65).withOpacity(0.1),
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                // Custom Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFF8A65),
                        Color(0xFFFFB74D),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFFFF8A65).withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Top row with back button and actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back_ios_rounded,
                                  color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                          Row(
                            children: [
                              _buildActionButton(
                                icon: Icons.print_rounded,
                                onPressed: () => _generateAndPrintPdf(
                                    filteredEmployees, employeeProvider, employees),
                              ),
                              const SizedBox(width: 12),
                              _buildActionButton(
                                icon: Icons.share_rounded,
                                onPressed: () => _sharePdf(
                                    filteredEmployees, employeeProvider, employees),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Title with icon
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.assignment_turned_in_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            languageProvider.isEnglish
                                ? 'Attendance Report'
                                : 'حاضری کی رپورٹ',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Filter Section
                Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Color(0xFFFFB74D).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.filter_list_rounded,
                                color: Color(0xFFFF8A65)),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            languageProvider.isEnglish ? 'Filters' : 'فلٹر',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Search Field
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: TextField(
                          decoration: InputDecoration(
                            labelText: languageProvider.isEnglish
                                ? 'Search by Name'
                                : 'نام سے تلاش کریں۔',
                            prefixIcon: Icon(Icons.search_rounded,
                                color: Color(0xFFFF8A65)),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(16),
                            labelStyle: TextStyle(color: Colors.grey.shade600),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _searchName = value;
                            });
                          },
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Date Range Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final pickedDateRange = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(20001),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: ColorScheme.light(
                                      primary: Color(0xFFFF8A65),
                                      onPrimary: Colors.white,
                                      surface: Colors.white,
                                      onSurface: Colors.grey.shade800,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (pickedDateRange != null) {
                              setState(() {
                                _dateRange = pickedDateRange;
                              });
                            }
                          },
                          icon: const Icon(Icons.date_range_rounded),
                          label: Text(
                            languageProvider.isEnglish
                                ? 'Select Date Range'
                                : 'تاریخ کی حد منتخب کریں۔',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Color(0xFFFF8A65),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Employee List
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    child: filteredEmployees.isEmpty
                        ? _buildEmptyState(languageProvider)
                        : ListView.builder(
                      itemCount: filteredEmployees.length,
                      itemBuilder: (context, index) {
                        final employeeId = filteredEmployees[index];
                        return _buildEmployeeCard(
                          employeeId,
                          employeeProvider,
                          employees,
                          languageProvider,
                          index,
                        );
                      },
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

  Widget _buildActionButton({required IconData icon, required VoidCallback onPressed}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 24),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildEmptyState(LanguageProvider languageProvider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 64,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            languageProvider.isEnglish
                ? 'No employees found'
                : 'کوئی ملازم نہیں ملا',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            languageProvider.isEnglish
                ? 'Try adjusting your search criteria'
                : 'اپنے تلاش کے معیار کو ایڈجسٹ کرنے کی کوشش کریں',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeCard(
      String employeeId,
      EmployeeProvider employeeProvider,
      Map<String, Map<String, String>> employees,
      LanguageProvider languageProvider,
      int index,
      ) {
    return Container(
      margin: EdgeInsets.only(bottom: 16, top: index == 0 ? 0 : 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: FutureBuilder<Map<String, Map<String, dynamic>>>(
        future: _dateRange != null
            ? employeeProvider.getAttendanceForDateRange(employeeId, _dateRange!)
            : Future.value({}),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF8A65)),
                    strokeWidth: 3,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Loading...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          } else if (snapshot.hasData) {
            final attendanceData = snapshot.data!;
            final employeeName = employees[employeeId]!['name']!;

            if (attendanceData.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Color(0xFFFFB74D).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.person_outline_rounded,
                          color: Color(0xFFFF8A65)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            employeeName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            languageProvider.isEnglish
                                ? 'No attendance marked for the selected range'
                                : 'منتخب کردہ رینج کے لیے کوئی حاضری نشان زد نہیں ہے۔',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            return Theme(
              data: Theme.of(context).copyWith(
                dividerColor: Colors.transparent,
              ),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.all(20),
                childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFFFFB74D).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.person_rounded, color: Color(0xFFFF8A65)),
                ),
                title: Text(
                  employeeName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Container(
                  margin: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Color(0xFFFFB74D).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${attendanceData.length} ${languageProvider.isEnglish ? "records" : "ریکارڈز"}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFFF8A65),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                children: attendanceData.entries.map((entry) {
                  final date = entry.key;
                  final attendance = entry.value;
                  final status = attendance['status'] ?? 'N/A';

                  Color statusColor = Colors.grey;
                  Color statusBgColor = Colors.grey.shade100;

                  if (status.toLowerCase().contains('present')) {
                    statusColor = Colors.green.shade700;
                    statusBgColor = Colors.green.shade50;
                  } else if (status.toLowerCase().contains('absent')) {
                    statusColor = Colors.red.shade700;
                    statusBgColor = Colors.red.shade50;
                  } else if (status.toLowerCase().contains('late')) {
                    statusColor = Colors.orange.shade700;
                    statusBgColor = Colors.orange.shade50;
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.calendar_today_rounded,
                                      size: 16, color: Colors.grey.shade600),
                                  const SizedBox(width: 8),
                                  Text(
                                    date,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: statusBgColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                              if (attendance['description'] != null &&
                                  attendance['description']!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.description_rounded,
                                        size: 16, color: Colors.grey.shade600),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        attendance['description'] ?? 'N/A',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (attendance['time'] != null) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.access_time_rounded,
                                        size: 16, color: Colors.grey.shade600),
                                    const SizedBox(width: 8),
                                    Text(
                                      attendance['time'] ?? 'N/A',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: Icon(Icons.delete_outline_rounded,
                                color: Colors.red.shade600),
                            onPressed: () async {
                              // Show confirmation dialog
                              final bool? confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  title: Text(
                                    languageProvider.isEnglish
                                        ? 'Delete Attendance'
                                        : 'حاضری حذف کریں',
                                  ),
                                  content: Text(
                                    languageProvider.isEnglish
                                        ? 'Are you sure you want to delete this attendance record?'
                                        : 'کیا آپ واقعی اس حاضری کا ریکارڈ حذف کرنا چاہتے ہیں؟',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(false),
                                      child: Text(
                                        languageProvider.isEnglish ? 'Cancel' : 'منسوخ',
                                        style: TextStyle(color: Colors.grey.shade600),
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.of(context).pop(true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red.shade600,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: Text(
                                        languageProvider.isEnglish ? 'Delete' : 'حذف کریں',
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              );

                              if (confirmed == true) {
                                try {
                                  await employeeProvider.deleteAttendance(employeeId, date);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(languageProvider.isEnglish
                                          ? 'Attendance deleted successfully'
                                          : 'حاضری کامیابی سے حذف ہو گئی'),
                                      backgroundColor: Colors.green,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(languageProvider.isEnglish
                                          ? 'Error deleting attendance: $e'
                                          : 'حاضری حذف کرنے میں خرابی: $e'),
                                      backgroundColor: Colors.red,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            );
          } else {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.error_outline_rounded, color: Colors.red.shade600),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          employees[employeeId]!['name']!,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          languageProvider.isEnglish
                              ? 'Error fetching attendance'
                              : 'حاضری حاصل کرنے میں خرابی۔',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Future<pw.MemoryImage> _createTextImage(String text) async {
    // Create a custom painter with the Urdu text
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromPoints(Offset(0, 0), Offset(500, 50)));
    final paint = Paint()..color = Colors.black;

    final textStyle = TextStyle(fontSize: 15, fontFamily: 'JameelNoori',color: Colors.black,fontWeight: FontWeight.bold);  // Set custom font here if necessary
    final textSpan = TextSpan(text: text, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.left,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(canvas, Offset(0, 0));

    // Create image from the canvas
    final picture = recorder.endRecording();
    final img = await picture.toImage(textPainter.width.toInt(), textPainter.height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();

    return pw.MemoryImage(buffer);  // Return the image as MemoryImage
  }

  Future<Uint8List> _generatePdfBytes(
      List<String> filteredEmployees,
      EmployeeProvider employeeProvider,
      Map<String, Map<String, String>> employees)
  async {
    final pdf = pw.Document();

    // Load the footer logo and header logo
    final ByteData footerBytes = await rootBundle.load('assets/images/devlogo.png');
    final footerBuffer = footerBytes.buffer.asUint8List();
    final footerLogo = pw.MemoryImage(footerBuffer);

    final ByteData headerBytes = await rootBundle.load('assets/images/logo.png');
    final headerBuffer = headerBytes.buffer.asUint8List();
    final headerLogo = pw.MemoryImage(headerBuffer);

    final employeeAttendances = await Future.wait(
      filteredEmployees.map((employeeId) async {
        if (_dateRange != null) {
          return MapEntry(
            employeeId,
            await employeeProvider.getAttendanceForDateRange(employeeId, _dateRange!),
          );
        }
        return MapEntry(employeeId, {});
      }),
    );

    // Collect rows for the table in an async way
    List<pw.TableRow> tableRows = [];
    for (var entry in employeeAttendances) {
      final employeeId = entry.key;
      final attendanceData = entry.value;
      final employeeName = employees[employeeId]!['name']!;

      for (var dateEntry in attendanceData.entries) {
        final date = dateEntry.key;
        final attendance = dateEntry.value;

        // Await the image generation for employee name and description
        final employeeNameImage = await _createTextImage(employeeName);
        final descriptionImage = await _createTextImage(attendance['description'] ?? 'N/A');

        tableRows.add(pw.TableRow(
          children: [
            pw.Text(date),
            pw.Image(employeeNameImage, dpi: 1000), // Employee name as image
            pw.Text(attendance['status'] ?? 'N/A'),
            pw.Image(descriptionImage, dpi: 1000), // Description as image
          ],
        ));
      }
    }

    // Get the first employee's name for the header (or use your own logic)
    final firstEmployeeId = filteredEmployees.isNotEmpty ? filteredEmployees.first : null;
    final firstEmployeeName = firstEmployeeId != null ? employees[firstEmployeeId]!['name']! : 'N/A';
    final firstEmployeeNameImage = await _createTextImage(firstEmployeeName);
// Get language provider first
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

// Update the header text logic with language support
    final headerText = filteredEmployees.length > 1
        ? (languageProvider.isEnglish ? 'ALL Employees' : 'تمام ملازمین')
        : firstEmployeeName;

    final headerTextImage = await _createTextImage(headerText);
    // Add the collected rows to the PDF table using MultiPage
    pdf.addPage(
      pw.MultiPage(
        // Set minimal margins for A4 paper
        pageFormat: PdfPageFormat.a4.copyWith(
          marginTop: 10,    // ~3.5mm (10 points)
          marginBottom: 10,
          marginLeft: 10,
          marginRight: 10,
        ),
        // Header: Logo on the top-right corner, "Attendance Report" text, and employee name
        header: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 10), // Add padding under the header
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Attendance Report',
                      style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Image(headerTextImage, width: 150, height: 50, dpi: 2000), // Changed here
                    pw.Text('Zulfiqar Ahmad: 03006316202',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Muhammad Irfan: 03008167446',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.Image(headerLogo, width: 100, height: 100, dpi: 1000), // Display the logo at the top
              ],
            ),
          );
        },
        // Footer: Footer content at the bottom of every page
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.bottomCenter,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Column(
              children: [
                pw.Divider(),
                pw.SizedBox(height: 10), // Add padding under the logo
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Image(footerLogo, width: 30, height: 30, dpi: 2000), // Footer logo
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          'Dev Valley Software House',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(
                          'Contact: 0303-4889663',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Table(
                  border: pw.TableBorder.all(width: 1, color: PdfColors.black),
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColors.grey300), // Add background color to header rowss
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Employee Name', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Status', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                      ],
                    ),
                    ...tableRows,
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );
    return pdf.save();
  }

  Future<void> _generateAndPrintPdf(
      List<String> filteredEmployees,
      EmployeeProvider employeeProvider,
      Map<String, Map<String, String>> employees)
  async {
    try {
      final pdfBytes = await _generatePdfBytes(filteredEmployees, employeeProvider, employees);
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error printing PDF: $e')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();

    final today = DateTime.now();
    _dateRange = DateTimeRange(
      start: DateTime(today.year, today.month, today.day),
      end: DateTime(today.year, today.month, today.day),
    );
  }

}
