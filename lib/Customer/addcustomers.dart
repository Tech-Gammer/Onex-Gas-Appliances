// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../Provider/customerprovider.dart';
// import '../Provider/lanprovider.dart';
//
// class AddCustomer extends StatefulWidget {
//   @override
//   State<AddCustomer> createState() => _AddCustomerState();
// }
//
// class _AddCustomerState extends State<AddCustomer> {
//   final _formKey = GlobalKey<FormState>();
//   String _name = '';
//   String _address = '';
//   String _phone = '';
//   String _city = '';
//
//   @override
//   Widget build(BuildContext context) {
//     final languageProvider = Provider.of<LanguageProvider>(context);
//
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(
//             // 'Add Customer',
//             languageProvider.isEnglish ? 'Add Customer' : 'کسٹمر شامل کریں۔',
//             style: TextStyle(color: Colors.white)),
//         backgroundColor: Colors.orange[300],
//         centerTitle: true,
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Form(
//           key: _formKey,
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 // 'Customer Details',
//                 languageProvider.isEnglish ? 'Customer Details' : 'کسٹمر کی تفصیلات',
//
//                 style: TextStyle(
//                   fontSize: 24,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.orange[300],
//                 ),
//               ),
//               SizedBox(height: 20),
//               TextFormField(
//                 decoration: InputDecoration(
//                   labelText: languageProvider.isEnglish ? 'Name' : 'نام',
//
//                   labelStyle: TextStyle(color: Colors.orange[300]),
//                   border: OutlineInputBorder(),
//                   focusedBorder: OutlineInputBorder(
//                     borderSide: BorderSide(color: Colors.orange),
//                   ),
//                 ),
//                 onSaved: (value) => _name = value!,
//                 validator: (value) =>
//                 value!.isEmpty ? 'Please enter the customer\'s name' : null,
//               ),
//               SizedBox(height: 16),
//               TextFormField(
//                 decoration: InputDecoration(
//                   labelText:  languageProvider.isEnglish ? 'Address' : 'پتہ',
//                   labelStyle: TextStyle(color: Colors.orange[300]),
//                   border: OutlineInputBorder(),
//                   focusedBorder: OutlineInputBorder(
//                     borderSide: BorderSide(color: Colors.orange),
//                   ),
//                 ),
//                 onSaved: (value) => _address = value!,
//                 validator: (value) =>
//                 value!.isEmpty ? 'Please enter the customer\'s address' : null,
//               ),
//               // 🆕 City
//               TextFormField(
//                 decoration: InputDecoration(
//                   labelText: languageProvider.isEnglish ? 'City' : 'شہر',
//                   labelStyle: TextStyle(color: Colors.orange[300]),
//                   border: OutlineInputBorder(),
//                   focusedBorder: OutlineInputBorder(
//                     borderSide: BorderSide(color: Colors.orange),
//                   ),
//                 ),
//                 onSaved: (value) => _city = value!,
//                 validator: (value) =>
//                 value!.isEmpty ? 'Please enter the customer\'s city' : null,
//               ),
//               SizedBox(height: 16),
//               TextFormField(
//                 decoration: InputDecoration(
//                   labelText: languageProvider.isEnglish ? 'ُPhone Number' : 'موبائل نمبر',
//                   labelStyle: TextStyle(color: Colors.orange[300]),
//                   border: OutlineInputBorder(),
//                   focusedBorder: OutlineInputBorder(
//                     borderSide: BorderSide(color: Colors.orange),
//                   ),
//                 ),
//                 keyboardType: TextInputType.phone,
//                 onSaved: (value) => _phone = value!,
//                 validator: (value) {
//                   if (value!.isEmpty) return 'Please enter the customer\'s phone number';
//                   if (!RegExp(r'^[0-9]{10,15}$').hasMatch(value)) return 'Please enter a valid phone number';
//                   return null;
//                 },
//               ),
//               SizedBox(height: 20),
//               Align(
//                 alignment: Alignment.center,
//                 child: ElevatedButton(
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.orange[300],
//                     padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 40),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(10),
//                     ),
//                   ),
//                   onPressed: () => _saveCustomer(context),
//                   child: Text(
//                     // 'Save',
//                     languageProvider.isEnglish ? 'Save' : 'محفوظ کریں۔',
//
//                     style: const TextStyle(
//                     fontSize: 18,
//                     color: Colors.white,
//                     fontWeight: FontWeight.bold,
//                   ),),
//
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   void _saveCustomer(BuildContext context) {
//     if (_formKey.currentState!.validate()) {
//       _formKey.currentState!.save();
//       Provider.of<CustomerProvider>(context, listen: false).addCustomer(_name, _address, _phone,_city);
//       Navigator.pop(context);
//     }
//   }
// }
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../Provider/customerprovider.dart';
import '../Provider/lanprovider.dart';

class AddCustomer extends StatefulWidget {
  @override
  State<AddCustomer> createState() => _AddCustomerState();
}

class _AddCustomerState extends State<AddCustomer> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _balanceController = TextEditingController(text: '0.00');

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
            languageProvider.isEnglish ? 'Add Customer' : 'کسٹمر شامل کریں۔',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.orange[300],
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  languageProvider.isEnglish ? 'Customer Details' : 'کسٹمر کی تفصیلات',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[300],
                  ),
                ),
                SizedBox(height: 20),
                // Name Field
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: languageProvider.isEnglish ? 'Name' : 'نام',
                    labelStyle: TextStyle(color: Colors.orange[300]),
                    border: OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.orange),
                    ),
                  ),
                  validator: (value) => value!.isEmpty
                      ? languageProvider.isEnglish
                      ? 'Please enter the customer\'s name'
                      : 'براہ کرم کسٹمر کا نام درج کریں'
                      : null,
                ),
                SizedBox(height: 16),
                // Address Field
                TextFormField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    labelText: languageProvider.isEnglish ? 'Address' : 'پتہ',
                    labelStyle: TextStyle(color: Colors.orange[300]),
                    border: OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.orange),
                    ),
                  ),
                  validator: (value) => value!.isEmpty
                      ? languageProvider.isEnglish
                      ? 'Please enter the customer\'s address'
                      : 'براہ کرم کسٹمر کا پتہ درج کریں'
                      : null,
                ),
                SizedBox(height: 16),
                // City Field
                TextFormField(
                  controller: _cityController,
                  decoration: InputDecoration(
                    labelText: languageProvider.isEnglish ? 'City' : 'شہر',
                    labelStyle: TextStyle(color: Colors.orange[300]),
                    border: OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.orange),
                    ),
                  ),
                  validator: (value) => value!.isEmpty
                      ? languageProvider.isEnglish
                      ? 'Please enter the customer\'s city'
                      : 'براہ کرم کسٹمر کا شہر درج کریں'
                      : null,
                ),
                SizedBox(height: 16),
                // Phone Field
                TextFormField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: languageProvider.isEnglish ? 'Phone Number' : 'موبائل نمبر',
                    labelStyle: TextStyle(color: Colors.orange[300]),
                    border: OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.orange),
                    ),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value!.isEmpty) {
                      return languageProvider.isEnglish
                          ? 'Please enter the customer\'s phone number'
                          : 'براہ کرم کسٹمر کا فون نمبر درج کریں';
                    }
                    if (!RegExp(r'^[0-9]{10,15}$').hasMatch(value)) {
                      return languageProvider.isEnglish
                          ? 'Please enter a valid phone number'
                          : 'براہ کرم درست فون نمبر درج کریں';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                // Opening Balance Field
                TextFormField(
                  controller: _balanceController,
                  decoration: InputDecoration(
                    labelText: languageProvider.isEnglish
                        ? 'Opening Balance'
                        : 'ابتدائی بیلنس',
                    labelStyle: TextStyle(color: Colors.orange[300]),
                    border: OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.orange),
                    ),
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value!.isEmpty) {
                      return languageProvider.isEnglish
                          ? 'Please enter opening balance (0 if none)'
                          : 'براہ کرم ابتدائی بیلنس درج کریں (اگر کوئی نہیں تو 0)';
                    }
                    if (double.tryParse(value) == null) {
                      return languageProvider.isEnglish
                          ? 'Please enter a valid number'
                          : 'براہ کرم درست نمبر درج کریں';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 20),
                // Save Button
                Align(
                  alignment: Alignment.center,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[300],
                      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => _saveCustomer(context),
                    child: Text(
                      languageProvider.isEnglish ? 'Save' : 'محفوظ کریں۔',
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
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

  void _saveCustomer(BuildContext context) {
    if (_formKey.currentState!.validate()) {
      final openingBalance = double.tryParse(_balanceController.text) ?? 0.0;
      Provider.of<CustomerProvider>(context, listen: false).addCustomer(
        _nameController.text,
        _addressController.text,
        _phoneController.text,
        _cityController.text,
        openingBalance,
      );
      Navigator.pop(context);
    }
  }
}