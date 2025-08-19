import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
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

  // Add date/time for opening balance
  DateTime _openingBalanceDate = DateTime.now();

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime(BuildContext context) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    // First pick date
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _openingBalanceDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null) {
      // Then pick time
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_openingBalanceDate),
      );

      if (pickedTime != null) {
        setState(() {
          _openingBalanceDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
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
                SizedBox(height: 16),

                // Opening Balance Date/Time Field
                Card(
                  elevation: 2,
                  child: ListTile(
                    leading: Icon(Icons.calendar_today, color: Colors.orange[300]),
                    title: Text(
                      languageProvider.isEnglish
                          ? 'Opening Balance Date & Time'
                          : 'ابتدائی بیلنس کی تاریخ اور وقت',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.orange[300],
                      ),
                    ),
                    subtitle: Text(
                      DateFormat('dd/MM/yyyy - HH:mm').format(_openingBalanceDate),
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.orange[600],
                      ),
                    ),
                    trailing: Icon(Icons.edit, color: Colors.orange[300]),
                    onTap: () => _selectDateTime(context),
                  ),
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
        _openingBalanceDate, // Pass the selected date/time
      );
      Navigator.pop(context);
    }
  }
}