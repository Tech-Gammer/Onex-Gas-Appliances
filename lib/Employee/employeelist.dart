
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Provider/employeeprovider.dart';
import '../Provider/lanprovider.dart';
import 'addemployee.dart';
import 'attendance.dart';

class EmployeeListPage extends StatefulWidget {
  @override
  _EmployeeListPageState createState() => _EmployeeListPageState();
}

class _EmployeeListPageState extends State<EmployeeListPage>
    with TickerProviderStateMixin {
  TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Map<String, dynamic> _todaysAttendance = {};
  bool _isAttendanceLoading = true;
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

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });

    // Start the animation
    _animationController.forward();

    // Fetch attendance data when the page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchTodaysAttendance();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchTodaysAttendance() async {
    if (!mounted) return;

    setState(() {
      _isAttendanceLoading = true;
    });

    try {
      final provider = Provider.of<EmployeeProvider>(context, listen: false);
      final today = DateTime.now();
      final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final allEmployees = provider.employees;
      Map<String, dynamic> fetchedAttendance = {};

      // Fetch attendance for each employee
      for (var entry in allEmployees.entries) {
        final employeeId = entry.key;
        final attendanceMap = await provider.getAttendanceForDateRange(
          employeeId,
          DateTimeRange(start: today, end: today),
        );

        if (attendanceMap.containsKey(dateKey)) {
          fetchedAttendance[employeeId] = attendanceMap[dateKey];
        }
      }

      if (mounted) {
        setState(() {
          _todaysAttendance = fetchedAttendance;
          _isAttendanceLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAttendanceLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load attendance: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    final employeeProvider = Provider.of<EmployeeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isEnglish = languageProvider.isEnglish;

    final filteredEmployees = employeeProvider.employees.entries.where((entry) {
      final employee = entry.value;
      return employee['name']?.toLowerCase().contains(_searchQuery) ?? false;
    }).toList();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFB74D).withOpacity(0.8),
              Color(0xFFFF8A65),
              Color(0xFFFFB74D).withOpacity(0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildModernAppBar(isEnglish),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _fetchTodaysAttendance,
                  child: Container(
                    margin: EdgeInsets.only(top: 20),
                    decoration: BoxDecoration(
                      color: Color(0xFFFEF7F2),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            _buildGlassmorphicSearchBar(isEnglish),
                            const SizedBox(height: 25),
                            _buildStatsRow(filteredEmployees.length, isEnglish),
                            const SizedBox(height: 20),
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  if (constraints.maxWidth > 600) {
                                    return _buildWebLayout(isEnglish, filteredEmployees);
                                  }
                                  return _buildMobileLayout(isEnglish, filteredEmployees);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildFloatingActionButtons(isEnglish),
    );
  }

  Widget _buildModernAppBar(bool isEnglish) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                children: [
                  Text(
                    isEnglish ? 'Employee Management' : 'ملازمین کا انتظام',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    isEnglish ? 'Team Overview' : 'ٹیم کا جائزہ',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: 48,
          ),
        ],
      ),
    );
  }

  Widget _buildGlassmorphicSearchBar(bool isEnglish) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.8),
            Colors.white.withOpacity(0.9),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 20,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: isEnglish ? 'Search employees...' : 'ملازمین تلاش کریں...',
          hintStyle: TextStyle(color: Colors.grey[500], fontSize: 16),
          prefixIcon: Container(
            margin: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Color(0xFFFF8A65),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.search, color: Colors.white, size: 20),
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.clear, color: Colors.grey[500]),
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
              });
            },
          )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        ),
      ),
    );
  }

  Widget _buildStatsRow(int totalEmployees, bool isEnglish) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.people,
            title: isEnglish ? 'Total Employees' : 'کل ملازم',
            value: totalEmployees.toString(),
            color: Color(0xFF4CAF50),
          ),
        ),
        SizedBox(width: 15),
        Expanded(
          child: _buildStatCard(
            icon: Icons.check_circle,
            title: isEnglish ? 'Present Today' : 'آج حاضر',
            value: _todaysAttendance.values.where((v) => v['status'] == 'present').length.toString(),
            color: Color(0xFF2196F3),
          ),
        ),
        SizedBox(width: 15),
        Expanded(
          child: _buildStatCard(
            icon: Icons.cancel,
            title: isEnglish ? 'Absent Today' : 'آج غیرحاضر',
            value: _todaysAttendance.values.where((v) => v['status'] == 'absent').length.toString(),
            color: Color(0xFFFF9800),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            spreadRadius: 0,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildWebLayout(bool isEnglish, List<MapEntry<String, Map<String, String>>> employees) {
    if (_isAttendanceLoading) {
      return Center(
        child: CircularProgressIndicator(),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 20,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SingleChildScrollView(
          child: DataTable(
            columnSpacing: 30,
            horizontalMargin: 30,
            dataRowHeight: 70,
            headingRowHeight: 60,
            headingRowColor: MaterialStateProperty.all(Color(0xFFFF8A65).withOpacity(0.1)),
            columns: [
              _buildDataColumn(isEnglish ? 'Employee' : 'ملازم'),
              _buildDataColumn(isEnglish ? 'Contact Info' : 'رابطے کی معلومات'),
              _buildDataColumn(isEnglish ? 'Status' : 'حالت'),
              _buildDataColumn(isEnglish ? 'Actions' : 'اعمال'),
            ],
            rows: employees.map((entry) => _buildDataRow(entry, isEnglish)).toList(),
          ),
        ),
      ),
    );
  }

  DataColumn _buildDataColumn(String label) {
    return DataColumn(
      label: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFFFF8A65),
          fontSize: 16,
        ),
      ),
    );
  }

  DataRow _buildDataRow(MapEntry<String, Map<String, String>> entry, bool isEnglish) {
    final id = entry.key;
    final employee = entry.value;
    final alreadyMarked = _todaysAttendance.containsKey(id);
    final attendanceStatus = _todaysAttendance[id]?['status'];

    return DataRow(
      cells: [
        DataCell(
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Color(0xFFFFB74D).withOpacity(0.2),
                child: Text(
                  (employee['name'] ?? '').isNotEmpty
                      ? employee['name']![0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: Color(0xFFFF8A65),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    employee['name'] ?? '',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Colors.grey[800],
                    ),
                  ),
                  Text(
                    'ID: $id',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      employee['address'] ?? '',
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.phone, size: 14, color: Colors.grey[500]),
                  SizedBox(width: 4),
                  Text(
                    employee['phone'] ?? '',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ],
              ),
            ],
          ),
        ),
        DataCell(
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: alreadyMarked
                  ? (attendanceStatus == 'present'
                  ? Colors.green.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1))
                  : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: alreadyMarked
                    ? (attendanceStatus == 'present'
                    ? Colors.green
                    : Colors.red)
                    : Colors.grey,
                width: 1,
              ),
            ),
            child: Text(
              alreadyMarked
                  ? (attendanceStatus == 'present'
                  ? (isEnglish ? 'Present' : 'حاضر')
                  : (isEnglish ? 'Absent' : 'غیرحاضر'))
                  : (isEnglish ? 'Not Marked' : 'نشان نہیں لگایا'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: alreadyMarked
                    ? (attendanceStatus == 'present'
                    ? Colors.green[700]
                    : Colors.red[700])
                    : Colors.grey[600],
              ),
            ),
          ),
        ),
        DataCell(
          Row(
            children: [
              _buildModernActionButton(
                icon: Icons.edit,
                color: Color(0xFF2196F3),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AddEmployeePage(employeeId: id)),
                ),
              ),
              SizedBox(width: 8),
              _buildModernActionButton(
                icon: Icons.delete,
                color: Colors.red,
                onPressed: () => _confirmDelete(id),
              ),
              SizedBox(width: 12),
              _buildAttendanceButtons(id, isEnglish),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceButtons(String id, bool isEnglish) {
    if (_isAttendanceLoading) {
      return Container(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    final alreadyMarked = _todaysAttendance.containsKey(id);

    return Row(
      children: [
        _buildStatusButton(
          label: isEnglish ? 'Present' : 'حاضر',
          color: Colors.green,
          alreadyMarked: alreadyMarked,
          onPressed: () => _markAttendance(context, id, 'present'),
        ),
        SizedBox(width: 6),
        _buildStatusButton(
          label: isEnglish ? 'Absent' : 'غیرحاضر',
          color: Colors.red,
          alreadyMarked: alreadyMarked,
          onPressed: () => _markAttendance(context, id, 'absent'),
        ),
      ],
    );
  }

  Widget _buildModernActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: color, size: 18),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildStatusButton({
    required String label,
    required Color color,
    required bool alreadyMarked,
    required VoidCallback onPressed,
  }) {
    return Container(
      height: 32,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: alreadyMarked ? Colors.grey[300] : color,
          foregroundColor: alreadyMarked ? Colors.grey[600] : Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: alreadyMarked ? 0 : 2,
        ),
        onPressed: () {
          if (alreadyMarked) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Attendance already marked for today'),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          } else {
            onPressed();
          }
        },
        child: Text(
          label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(bool isEnglish, List<MapEntry<String, Map<String, String>>> employees) {
    if (_isAttendanceLoading) {
      return Center(
        child: CircularProgressIndicator(),
      );
    }
    return ListView.builder(
      itemCount: employees.length,
      itemBuilder: (context, index) {
        final entry = employees[index];
        final id = entry.key;
        final employee = entry.value;
        final alreadyMarked = _todaysAttendance.containsKey(id);
        final attendanceStatus = _todaysAttendance[id]?['status'];

        return Container(
          margin: EdgeInsets.only(bottom: 15),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, Color(0xFFFFF8F5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.15),
                spreadRadius: 0,
                blurRadius: 15,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFFF8A65), Color(0xFFFFB74D)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Center(
                        child: Text(
                          (employee['name'] ?? '').isNotEmpty
                              ? employee['name']![0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            employee['name'] ?? '',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          Text(
                            'ID: $id',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                          SizedBox(height: 8),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: alreadyMarked
                                  ? (attendanceStatus == 'present'
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.red.withOpacity(0.1))
                                  : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              alreadyMarked
                                  ? (attendanceStatus == 'present'
                                  ? (isEnglish ? 'Present Today' : 'آج حاضر')
                                  : (isEnglish ? 'Absent Today' : 'آج غیرحاضر'))
                                  : (isEnglish ? 'Not Marked' : 'نشان نہیں لگایا'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: alreadyMarked
                                    ? (attendanceStatus == 'present'
                                    ? Colors.green[700]
                                    : Colors.red[700])
                                    : Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 15),
                _buildMobileInfoRow(Icons.location_on, employee['address'] ?? '', Colors.orange),
                _buildMobileInfoRow(Icons.phone, employee['phone'] ?? '', Colors.blue),
                SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          _buildStatusButton(
                            label: isEnglish ? 'Present' : 'حاضر',
                            color: Colors.green,
                            alreadyMarked: alreadyMarked,
                            onPressed: () => _markAttendance(context, id, 'present'),
                          ),
                          SizedBox(width: 10),
                          _buildStatusButton(
                            label: isEnglish ? 'Absent' : 'غیرحاضر',
                            color: Colors.red,
                            alreadyMarked: alreadyMarked,
                            onPressed: () => _markAttendance(context, id, 'absent'),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 15),
                    _buildModernActionButton(
                      icon: Icons.edit,
                      color: Color(0xFF2196F3),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => AddEmployeePage(employeeId: id)),
                      ),
                    ),
                    SizedBox(width: 10),
                    _buildModernActionButton(
                      icon: Icons.delete,
                      color: Colors.red,
                      onPressed: () => _confirmDelete(id),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileInfoRow(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButtons(bool isEnglish) {
    return FloatingActionButton(
      heroTag: "main_fab",
      onPressed: () {
        // Show a menu with both options
        showModalBottomSheet(
          context: context,
          builder: (context) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.add),
                title: Text(isEnglish ? 'Add Employee' : 'ملازم شامل کریں'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AddEmployeePage()),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.analytics),
                title: Text(isEnglish ? 'Attendance Report' : 'حاضری کی رپورٹ'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AttendanceReportPage()),
                  );
                },
              ),
            ],
          ),
        );
      },
      backgroundColor: Color(0xFFFF8A65),
      child: Icon(Icons.menu, color: Colors.white),
    );
  }

  void _confirmDelete(String id) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final isEnglish = languageProvider.isEnglish;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 28),
            SizedBox(width: 10),
            Text(
              isEnglish ? 'Delete Employee' : 'ملازم حذف کریں',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          isEnglish
              ? 'Are you sure you want to permanently delete this employee? This action cannot be undone.'
              : 'کیا آپ واقعی اس ملازم کو مستقل طور پر حذف کرنا چاہتے ہیں؟ یہ عمل واپس نہیں ہو سکتا۔',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              isEnglish ? 'Cancel' : 'منسوخ کریں',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              try {
                await Provider.of<EmployeeProvider>(context, listen: false)
                    .deleteEmployee(id);
                Navigator.pop(ctx);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isEnglish
                        ? 'Deletion failed: $e'
                        : 'حذف ہونے میں ناکام: $e'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
            },
            child: Text(
              isEnglish ? 'Delete' : 'حذف کریں',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _markAttendance(BuildContext parentContext, String id, String status) {
    final languageProvider = Provider.of<LanguageProvider>(parentContext, listen: false);

    String description = '';
    showDialog(
      context: parentContext,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            languageProvider.isEnglish
                ? 'Mark Attendance as $status'
                : 'کے طور پر حاضری درج کریں$status',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                languageProvider.isEnglish
                    ? 'Please provide a description for the $status status:'
                    : ' کی حالت کے لئے وضاحت فراہم کریں:''$status',
              ),
              TextField(
                onChanged: (value) {
                  description = value;
                },
                decoration: InputDecoration(
                  hintText: languageProvider.isEnglish ? 'Enter description' : 'وضاحت درج کریں',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: Text(languageProvider.isEnglish ? 'Cancel' : 'رد کریں'),
            ),

            ElevatedButton(
              onPressed: () async {
                final currentDate = DateTime.now();
                final dateKey = '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}';

                // Mark attendance
                await Provider.of<EmployeeProvider>(parentContext, listen: false)
                    .markAttendance(parentContext, id, status, description, currentDate);

                // Close the dialog first
                Navigator.pop(dialogContext);

                // Update local state
                if (mounted) {
                  setState(() {
                    _todaysAttendance[id] = {
                      'status': status,
                      'description': description,
                      'date': dateKey,
                    };
                  });
                }

                // Wait for dialog to fully close before showing SnackBar
                await Future.delayed(Duration(milliseconds: 300));
// Refresh the attendance data
                await _fetchTodaysAttendance();
                if (mounted) {
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    SnackBar(
                      content: Text(languageProvider.isEnglish
                          ? 'Attendance marked successfully!'
                          : 'حاضری کامیابی سے درج ہو گئی!'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)
                      ),
                    ),
                  );
                }
              },
              child: Text(languageProvider.isEnglish ? 'OK' : 'ٹھیک ہے'),
            ),
          ],
        );
      },
    );
  }

    }

