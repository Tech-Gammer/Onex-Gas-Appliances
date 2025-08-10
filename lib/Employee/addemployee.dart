// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
//
// import '../Provider/employeeprovider.dart';
// import '../Provider/lanprovider.dart';
//
// class AddEmployeePage extends StatefulWidget {
//   final String? employeeId; // Null for adding, non-null for editing
//
//   AddEmployeePage({this.employeeId});
//
//   @override
//   _AddEmployeePageState createState() => _AddEmployeePageState();
// }
//
// class _AddEmployeePageState extends State<AddEmployeePage> {
//   final _formKey = GlobalKey<FormState>();
//   final _nameController = TextEditingController();
//   final _addressController = TextEditingController();
//   final _phoneController = TextEditingController();
//   bool _isSaving = false; // Track if the save operation is in progress
//   @override
//   void initState() {
//     super.initState();
//     if (widget.employeeId != null) {
//       _loadEmployeeData();
//     }
//   }
//
//   void _loadEmployeeData() {
//     final employee = Provider.of<EmployeeProvider>(context, listen: false)
//         .employees[widget.employeeId!];
//     if (employee != null) {
//       _nameController.text = employee['name'] ?? '';
//       _addressController.text = employee['address'] ?? '';
//       _phoneController.text = employee['phone'] ?? '';
//     }
//   }
//
//   Future<void> _saveEmployee() async {
//     if (_formKey.currentState!.validate()) {
//       setState(() {
//         _isSaving = true; // Disable the button
//       });
//       final employeeData = {
//         'name': _nameController.text,
//         'address': _addressController.text,
//         'phone': _phoneController.text,
//       };
//
//       final provider = Provider.of<EmployeeProvider>(context, listen: false);
//       if (widget.employeeId == null) {
//         // Add new employee
//         String newId = provider.employees.length.toString();
//         provider.addOrUpdateEmployee(newId, employeeData);
//       } else {
//         // Update existing employees
//         provider.addOrUpdateEmployee(widget.employeeId!, employeeData);
//       }
//
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Employee saved successfully!')),
//       );
//       // Delay to simulate saving operation, then re-enable the button
//       await Future.delayed(Duration(seconds: 1));
//       setState(() {
//         _isSaving = false; // Re-enable the button
//       });
//       Navigator.pop(context);
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final languageProvider = Provider.of<LanguageProvider>(context);
//
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(
//           // widget.employeeId == null ? 'Add Employee' : 'Edit Employee',style: TextStyle(color: Colors.white),
//           widget.employeeId == null
//               ? (languageProvider.isEnglish ? 'Add Employee' : 'ملازم شامل کریں')
//               : (languageProvider.isEnglish ? 'Edit Employee' : 'ملازم کو ترمیم کریں'),
//           style: TextStyle(color: Colors.white),
//         ),
//         backgroundColor: Colors.teal,
//         centerTitle: true,
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Form(
//           key: _formKey,
//           child: Column(
//             children: [
//               const SizedBox(height: 20),
//               TextFormField(
//                 controller: _nameController,
//                 decoration: InputDecoration(
//                   labelText: languageProvider.isEnglish ? 'Name' : 'نام',
//                   labelStyle: TextStyle(color: Colors.teal.shade700),
//                   fillColor: Colors.white,
//                   filled: true,
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(8),
//                     borderSide: BorderSide.none,
//                   ),
//                   focusedBorder: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(8),
//                     borderSide: BorderSide(color: Colors.teal.shade700),
//                   ),
//                 ),
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return languageProvider.isEnglish
//                         ? 'Please enter a name'
//                         : 'براہ کرم نام درج کریں';                  }
//                   return null;
//                 },
//               ),
//               const SizedBox(height: 16),
//               TextFormField(
//                 controller: _addressController,
//                 decoration: InputDecoration(
//                   labelText: languageProvider.isEnglish ? 'Address' : 'پتہ',
//                   labelStyle: TextStyle(color: Colors.teal.shade700),
//                   fillColor: Colors.white,
//                   filled: true,
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(8),
//                     borderSide: BorderSide.none,
//                   ),
//                   focusedBorder: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(8),
//                     borderSide: BorderSide(color: Colors.teal.shade700),
//                   ),
//                 ),
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return languageProvider.isEnglish
//                         ? 'Please enter an address'
//                         : 'براہ کرم پتہ درج کریں';                  }
//                   return null;
//                 },
//               ),
//               const SizedBox(height: 16),
//               TextFormField(
//                 controller: _phoneController,
//                 decoration: InputDecoration(
//                   labelText: languageProvider.isEnglish
//                       ? 'Phone Number'
//                       : 'فون نمبر',
//                   labelStyle: TextStyle(color: Colors.teal.shade700),
//                   fillColor: Colors.white,
//                   filled: true,
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(8),
//                     borderSide: BorderSide.none,
//                   ),
//                   focusedBorder: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(8),
//                     borderSide: BorderSide(color: Colors.teal.shade700),
//                   ),
//                 ),
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return languageProvider.isEnglish
//                         ? 'Please enter a phone number'
//                         : 'براہ کرم فون نمبر درج کریں';                  }
//                   return null;
//                 },
//               ),
//               const SizedBox(height: 20),
//               ElevatedButton(
//                 // onPressed: _saveEmployee,
//                 onPressed: _isSaving ? null : _saveEmployee, // Disable button when saving
//
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.teal,
//                   padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 40),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(10),
//                   ),
//                 ),
//                 child: Text(
//                   // widget.employeeId == null ? 'Add Employee' : 'Save Changes',s
//                   widget.employeeId == null
//                       ? (languageProvider.isEnglish ? 'Add Employee' : 'ملازم شامل کریں')
//                       : (languageProvider.isEnglish ? 'Save Changes' : 'تبدیلیاں محفوظ کریں'),
//                   style: const TextStyle(
//                     fontSize: 18,
//                     color: Colors.white,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Provider/employeeprovider.dart';
import '../Provider/lanprovider.dart';

class AddEmployeePage extends StatefulWidget {
  final String? employeeId; // Null for adding, non-null for editing

  AddEmployeePage({this.employeeId});

  @override
  _AddEmployeePageState createState() => _AddEmployeePageState();
}

class _AddEmployeePageState extends State<AddEmployeePage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isSaving = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();

    if (widget.employeeId != null) {
      _loadEmployeeData();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _loadEmployeeData() {
    final employee = Provider.of<EmployeeProvider>(context, listen: false)
        .employees[widget.employeeId!];
    if (employee != null) {
      _nameController.text = employee['name'] ?? '';
      _addressController.text = employee['address'] ?? '';
      _phoneController.text = employee['phone'] ?? '';
    }
  }

  Future<void> _saveEmployee() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });

      final employeeData = {
        'name': _nameController.text,
        'address': _addressController.text,
        'phone': _phoneController.text,
      };

      final provider = Provider.of<EmployeeProvider>(context, listen: false);
      if (widget.employeeId == null) {
        String newId = provider.employees.length.toString();
        provider.addOrUpdateEmployee(newId, employeeData);
      } else {
        provider.addOrUpdateEmployee(widget.employeeId!, employeeData);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Employee saved successfully!'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      await Future.delayed(Duration(seconds: 1));
      setState(() {
        _isSaving = false;
      });
      Navigator.pop(context);
    }
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String labelEn,
    required String labelUr,
    required String validationEn,
    required String validationUr,
    required IconData icon,
    required LanguageProvider languageProvider,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: languageProvider.isEnglish ? labelEn : labelUr,
          labelStyle: TextStyle(
            color: Color(0xFFFF8A65),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Container(
            margin: EdgeInsets.all(8),
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Color(0xFFFF8A65).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: Color(0xFFFF8A65),
              size: 20,
            ),
          ),
          fillColor: Colors.white,
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Color(0xFFFF8A65), width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.red.shade400, width: 1),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        style: TextStyle(
          fontSize: 16,
          color: Colors.grey.shade800,
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return languageProvider.isEnglish ? validationEn : validationUr;
          }
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: Color(0xFFFF8A65),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.employeeId == null
                    ? (languageProvider.isEnglish ? 'Add Employee' : 'ملازم شامل کریں')
                    : (languageProvider.isEnglish ? 'Edit Employee' : 'ملازم کو ترمیم کریں'),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFF8A65),
                      Color(0xFFFFB74D),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -50,
                      top: -50,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 20,
                      top: 20,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      // Header Card
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.white, Color(0xFFFFB74D).withOpacity(0.1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFFFF8A65).withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 15,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: Color(0xFFFF8A65).withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                widget.employeeId == null
                                    ? Icons.person_add_rounded
                                    : Icons.edit_rounded,
                                size: 30,
                                color: Color(0xFFFF8A65),
                              ),
                            ),
                            SizedBox(height: 15),
                            Text(
                              languageProvider.isEnglish
                                  ? 'Employee Information'
                                  : 'ملازم کی معلومات',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFF8A65),
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              languageProvider.isEnglish
                                  ? 'Please fill in all the required fields'
                                  : 'براہ کرم تمام ضروری فیلڈز کو پُر کریں',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 30),

                      // Form Card
                      Container(
                        padding: EdgeInsets.all(25),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 15,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              _buildFormField(
                                controller: _nameController,
                                labelEn: 'Full Name',
                                labelUr: 'نام',
                                validationEn: 'Please enter a name',
                                validationUr: 'براہ کرم نام درج کریں',
                                icon: Icons.person_outline_rounded,
                                languageProvider: languageProvider,
                              ),

                              SizedBox(height: 20),

                              _buildFormField(
                                controller: _addressController,
                                labelEn: 'Address',
                                labelUr: 'پتہ',
                                validationEn: 'Please enter an address',
                                validationUr: 'براہ کرم پتہ درج کریں',
                                icon: Icons.location_on_outlined,
                                languageProvider: languageProvider,
                              ),

                              SizedBox(height: 20),

                              _buildFormField(
                                controller: _phoneController,
                                labelEn: 'Phone Number',
                                labelUr: 'فون نمبر',
                                validationEn: 'Please enter a phone number',
                                validationUr: 'براہ کرم فون نمبر درج کریں',
                                icon: Icons.phone_outlined,
                                languageProvider: languageProvider,
                              ),

                              SizedBox(height: 35),

                              // Save Button
                              Container(
                                width: double.infinity,
                                height: 55,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(15),
                                  gradient: _isSaving
                                      ? LinearGradient(
                                    colors: [Colors.grey.shade300, Colors.grey.shade400],
                                  )
                                      : LinearGradient(
                                    colors: [Color(0xFFFF8A65), Color(0xFFFFB74D)],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  boxShadow: _isSaving
                                      ? []
                                      : [
                                    BoxShadow(
                                      color: Color(0xFFFF8A65).withOpacity(0.3),
                                      spreadRadius: 1,
                                      blurRadius: 10,
                                      offset: Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _isSaving ? null : _saveEmployee,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                  ),
                                  child: _isSaving
                                      ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        languageProvider.isEnglish ? 'Saving...' : 'محفوظ کر رہا ہے...',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  )
                                      : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        widget.employeeId == null
                                            ? Icons.add_rounded
                                            : Icons.save_rounded,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        widget.employeeId == null
                                            ? (languageProvider.isEnglish ? 'Add Employee' : 'ملازم شامل کریں')
                                            : (languageProvider.isEnglish ? 'Save Changes' : 'تبدیلیاں محفوظ کریں'),
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}