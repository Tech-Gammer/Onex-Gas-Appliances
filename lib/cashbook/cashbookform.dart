import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../Models/cashbookModel.dart';
import '../Provider/lanprovider.dart';

class CashbookFormPage extends StatefulWidget {
  final DatabaseReference databaseRef;
  final CashbookEntry? editingEntry;

  const CashbookFormPage({
    Key? key,
    required this.databaseRef,
    this.editingEntry,
  }) : super(key: key);

  @override
  _CashbookFormPageState createState() => _CashbookFormPageState();
}

class _CashbookFormPageState extends State<CashbookFormPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _selectedType = 'cash_in';

  @override
  void initState() {
    super.initState();
    if (widget.editingEntry != null) {
      _descriptionController.text = widget.editingEntry!.description;
      _amountController.text = widget.editingEntry!.amount.toString();
      _selectedDate = widget.editingEntry!.dateTime;
      _selectedType = widget.editingEntry!.type;
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _saveEntry() {
    if (_formKey.currentState!.validate()) {
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      final entry = CashbookEntry(
        id: widget.editingEntry?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        description: _descriptionController.text,
        amount: double.parse(_amountController.text),
        dateTime: _selectedDate,
        type: _selectedType,
      );

      widget.databaseRef.child(entry.id!).set(entry.toJson()).then((_) {
        if (mounted) {
          Navigator.pop(context);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  widget.editingEntry == null
                      ? languageProvider.isEnglish
                      ? 'Entry added successfully'
                      : 'انٹری کامیابی سے شامل ہو گئی'
                      : languageProvider.isEnglish
                      ? 'Entry updated successfully'
                      : 'انٹری کامیابی سے اپ ڈیٹ ہو گئی'
              ),
            ),
          );
        }
      }).catchError((error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                languageProvider.isEnglish
                    ? 'Error saving entry: $error'
                    : 'انٹری محفوظ کرنے میں خرابی: $error',
              ),
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.editingEntry == null
              ? languageProvider.isEnglish ? 'Add Entry' : 'نیا اندراج'
              : languageProvider.isEnglish ? 'Edit Entry' : 'اندراج میں ترمیم کریں',
          style: const TextStyle(color: Colors.white),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF8A65), Color(0xFFFFB74D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: languageProvider.isEnglish ? 'Description' : 'تفصیل',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return languageProvider.isEnglish
                              ? 'Please enter a description'
                              : 'براہ کرم ایک تفصیل درج کریں';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _amountController,
                      decoration: InputDecoration(
                        labelText: languageProvider.isEnglish ? 'Amount' : 'رقم',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return languageProvider.isEnglish
                              ? 'Please enter an amount'
                              : 'براہ کرم ایک رقم درج کریں';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: Text('Date: ${DateFormat('yyyy-MM-dd – HH:mm').format(_selectedDate)}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );

                        if (pickedDate != null) {
                          final TimeOfDay? pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(_selectedDate),
                          );

                          if (pickedTime != null) {
                            setState(() {
                              _selectedDate = DateTime(
                                pickedDate.year,
                                pickedDate.month,
                                pickedDate.day,
                                pickedTime.hour,
                                pickedTime.minute,
                              );
                            });
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedType,
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedType = newValue!;
                        });
                      },
                      items: <String>['cash_in', 'cash_out']
                          .map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      decoration: const InputDecoration(
                        labelText: 'Type',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _saveEntry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[300],
                      ),
                      child: Text(
                        widget.editingEntry == null
                            ? languageProvider.isEnglish ? 'Add Entry' : 'انٹری جمع کریں'
                            : languageProvider.isEnglish ? 'Update Entry' : 'انٹری تبدیل کریں',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}