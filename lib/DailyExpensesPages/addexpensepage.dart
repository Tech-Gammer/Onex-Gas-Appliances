import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:onex_gas_appliances/DailyExpensesPages/viewexpensepage.dart';
import 'package:provider/provider.dart';
import '../Provider/lanprovider.dart';

class AddExpensePage extends StatefulWidget {
  @override
  _AddExpensePageState createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage> with TickerProviderStateMixin {
  final DatabaseReference dbRef = FirebaseDatabase.instance.ref("dailyKharcha");
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  double _openingBalance = 0.0;
  bool _isSaveButtonPressed = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

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
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack));

    _checkOpeningBalanceForToday();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Check if the opening balance is already set for the current day
  void _checkOpeningBalanceForToday() async {
    String formattedDate = DateFormat('dd:MM:yyyy').format(_selectedDate);
    dbRef.child("openingBalance").child(formattedDate).get().then((snapshot) {
      if (snapshot.exists) {
        final value = snapshot.value;
        if (value is num) {
          setState(() {
            _openingBalance = value.toDouble();
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid opening balance data')),
          );
        }
      } else {
        _showOpeningBalanceDialog();
      }
    });
  }

  // Show dialog to prompt user for opening balance
  void _showOpeningBalanceDialog() async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            languageProvider.isEnglish ? 'Set Opening Balance for Today:' : 'آج کے لیے اوپننگ بیلنس سیٹ کریں۔',
          ),
          content: TextField(
            keyboardType: TextInputType.number,
            onChanged: (value) {
              setState(() {
                _openingBalance = double.tryParse(value) ?? 0.0;
              });
            },
            decoration: InputDecoration(
              labelText: languageProvider.isEnglish ? 'Enter Opening Balance' : 'اوپننگ بیلنس درج کریں۔',
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں۔',
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(
                languageProvider.isEnglish ? 'Set' : 'سیٹ',
              ),
              onPressed: () {
                if (_openingBalance <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(
                      languageProvider.isEnglish ? 'Please enter a valid balance' : 'براہ کرم ایک درست بیلنس درج کریں۔',
                    )
                    ),
                  );
                } else {
                  Navigator.of(context).pop();
                  _saveOpeningBalanceToDB();
                }
              },
            ),
          ],
        );
      },
    );
  }

  // Save opening balance to Firebase (original balance is only saved once)
  void _saveOpeningBalanceToDB() {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    String formattedDate = DateFormat('dd:MM:yyyy').format(_selectedDate);

    dbRef.child("openingBalance").child(formattedDate).set(_openingBalance).then((_) {
      if (_openingBalance > 0) {
        dbRef.child("originalOpeningBalance").child(formattedDate).set(_openingBalance);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          languageProvider.isEnglish ? 'Opening balance set successfully' : 'اوپننگ بیلنس کامیابی سے سیٹ ہو گیا۔',
        )),
      );
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          languageProvider.isEnglish ? 'Error saving opening balance:$error' : '$errorاوپننگ بیلنس بچانے میں خرابی:' ,
        )),
      );
    });
  }

  void _saveExpense() async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    if (_descriptionController.text.isEmpty || _amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
            languageProvider.isEnglish ? 'Please fill in all fields' : 'براہ کرم تمام فیلڈز کو پُر کریں۔',
          )));
      return;
    }

    double expenseAmount = double.parse(_amountController.text);

    if (_openingBalance < expenseAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
            languageProvider.isEnglish ? 'Insufficient funds!' : 'ناکافی فنڈز!',
          )));
      return;
    }

    setState(() {
      _isSaveButtonPressed = true;
    });

    _openingBalance -= expenseAmount;

    String formattedDate = DateFormat('dd:MM:yyyy').format(_selectedDate);

    final data = {
      "description": _descriptionController.text,
      "amount": expenseAmount,
      "date": formattedDate,
    };

    try {
      await dbRef.child(formattedDate).child("expenses").push().set(data);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
            languageProvider.isEnglish ? 'Expense added successfully' : 'اخراجات کامیابی کے ساتھ شامل ہو گئے۔',
          )));
      _descriptionController.clear();
      _amountController.clear();
      setState(() {
        _selectedDate = DateTime.now();
      });

      _saveUpdatedOpeningBalance();
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
            languageProvider.isEnglish ? 'Error adding expense: $error' : 'اخراجات شامل کرنے میں خرابی:$error',
          )));
    } finally {
      setState(() {
        _isSaveButtonPressed = false;
      });
    }
  }

  // Save the updated opening balance (after deducting the expense)
  void _saveUpdatedOpeningBalance() {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    String formattedDate = DateFormat('dd:MM:yyyy').format(_selectedDate);
    dbRef.child("openingBalance").child(formattedDate).set(_openingBalance).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          languageProvider.isEnglish ? 'Opening balance updated successfully' : 'اوپننگ بیلنس کامیابی کے ساتھ اپ ڈیٹ ہو گیا۔',
        )),
      );
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          languageProvider.isEnglish ? 'Error updating opening balance: $error' : 'اوپننگ بیلنس کو اپ ڈیٹ کرنے میں خرابی: $error',
        )),
      );
    });
  }

  // Pick date for expense
  void _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
      });
      _checkOpeningBalanceForToday();
    }
  }

  void _adjustOpeningBalanceDialog() {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        TextEditingController adjustmentController = TextEditingController();
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            languageProvider.isEnglish
                ? 'Adjust Opening Balance'
                : 'اوپننگ بیلنس کو ایڈجسٹ کریں۔',
          ),
          content: TextField(
            controller: adjustmentController,
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            decoration: InputDecoration(
              labelText: languageProvider.isEnglish
                  ? 'Enter Adjustment Amount (+/-)'
                  : 'ایڈجسٹمنٹ رقم درج کریں (+/-)',
              hintText: languageProvider.isEnglish
                  ? 'Positive to add, negative to deduct'
                  : 'اضافہ کرنے کے لیے مثبت، کٹوتی کے لیے منفی',
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں۔',
              ),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: Text(
                languageProvider.isEnglish ? 'Adjust' : 'ایڈجسٹ کریں',
              ),
              onPressed: () {
                final adjustment = double.tryParse(adjustmentController.text);
                if (adjustment == null || adjustment == 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        languageProvider.isEnglish
                            ? 'Please enter a valid non-zero amount'
                            : 'براہ کرم ایک درست غیر صفر رقم درج کریں',
                      ),
                    ),
                  );
                } else {
                  Navigator.pop(context);
                  _updateOpeningBalance(adjustment);
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _updateOpeningBalance(double adjustment) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    String formattedDate = DateFormat('dd:MM:yyyy').format(_selectedDate);

    dbRef.child("openingBalance").child(formattedDate).get().then((openingSnapshot) {
      if (openingSnapshot.exists) {
        final currentOpening = openingSnapshot.value as num? ?? 0.0;

        dbRef.child("originalOpeningBalance").child(formattedDate).get().then((originalSnapshot) {
          final currentOriginal = originalSnapshot.value as num? ?? currentOpening.toDouble();
          final newOriginal = currentOriginal + adjustment;
          final updatedOpening = currentOpening + adjustment;

          if (newOriginal < 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  languageProvider.isEnglish
                      ? 'Original balance cannot be negative!'
                      : 'اصل بیلنس منفی نہیں ہو سکتا!',
                ),
              ),
            );
            return;
          }

          dbRef.update({
            "openingBalance/$formattedDate": updatedOpening,
            "originalOpeningBalance/$formattedDate": newOriginal,
          }).then((_) {
            setState(() => _openingBalance = updatedOpening);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  languageProvider.isEnglish
                      ? 'Balance adjusted by ${adjustment >= 0 ? '+' : ''}$adjustment'
                      : 'بیلنس ${adjustment >= 0 ? '+' : ''}$adjustment سے ایڈجسٹ',
                ),
              ),
            );
          });
        });
      }
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            languageProvider.isEnglish
                ? 'Error fetching balance: $error'
                : 'بیلنس حاصل کرنے میں خرابی: $error',
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final isEnglish = languageProvider.isEnglish;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF667eea),
              Color(0xFF764ba2),
              Color(0xFFf093fb),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildModernAppBar(isEnglish),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _buildFloatingDateCard(isEnglish),
                          const SizedBox(height: 20),
                          _buildBalanceCard(isEnglish),
                          const SizedBox(height: 24),
                          _buildExpenseForm(isEnglish),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernAppBar(bool isEnglish) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    child: Row(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => ViewExpensesPage()),
                    (Route<dynamic> route) => false,
              );
            },
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            isEnglish ? 'Add New Expense' : 'نیا اخراجات شامل کریں',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.tune, color: Colors.white),
            onPressed: _adjustOpeningBalanceDialog,
            tooltip: isEnglish ? 'Adjust Balance' : 'بیلنس ایڈجسٹ کریں',
          ),
        ),
      ],
    ),
  );

  Widget _buildFloatingDateCard(bool isEnglish) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF667eea).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                color: Color(0xFF667eea),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              isEnglish ? 'Expense Date' : 'اخراجات کی تاریخ',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D3748),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_selectedDate.day.toString().padLeft(2, '0')}:'
                  '${_selectedDate.month.toString().padLeft(2, '0')}:'
                  '${_selectedDate.year}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A202C),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.edit_calendar_rounded, size: 18),
                label: Text(isEnglish ? 'Change' : 'تبدیل کریں'),
                onPressed: _pickDate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _buildBalanceCard(bool isEnglish) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF11998e), Color(0xFF38ef7d)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF11998e).withOpacity(0.3),
          blurRadius: 20,
          offset: const Offset(0, 8),
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
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              isEnglish ? 'Available Balance' : 'دستیاب بیلنس',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Rs ${_openingBalance.toStringAsFixed(2)}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );

  Widget _buildExpenseForm(bool isEnglish) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 30,
          offset: const Offset(0, 15),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isEnglish ? 'Expense Details' : 'اخراجات کی تفصیلات',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3748),
          ),
        ),
        const SizedBox(height: 24),
        _buildStyledTextField(
          controller: _descriptionController,
          label: isEnglish ? 'Description' : 'تفصیل',
          icon: Icons.description_rounded,
          isEnglish: isEnglish,
        ),
        const SizedBox(height: 20),
        _buildStyledTextField(
          controller: _amountController,
          label: isEnglish ? 'Amount (Rs)' : 'رقم (روپے)',
          icon: Icons.attach_money_rounded,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          isEnglish: isEnglish,
        ),
        const SizedBox(height: 32),
        _buildModernSaveButton(isEnglish),
      ],
    ),
  );

  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    required bool isEnglish,
  }) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.1),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.grey[600],
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF667eea).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF667eea),
            size: 20,
          ),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF667eea), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      ),
    ),
  );

  Widget _buildModernSaveButton(bool isEnglish) => Container(
    width: double.infinity,
    height: 60,
    decoration: BoxDecoration(
      gradient: _isSaveButtonPressed
          ? const LinearGradient(colors: [Colors.grey, Colors.grey])
          : const LinearGradient(
        colors: [Color(0xFFf093fb), Color(0xFFf5576c)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: _isSaveButtonPressed
              ? Colors.grey.withOpacity(0.3)
              : const Color(0xFFf093fb).withOpacity(0.4),
          blurRadius: 15,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: ElevatedButton(
      onPressed: _isSaveButtonPressed ? null : _saveExpense,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: _isSaveButtonPressed
          ? Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            isEnglish ? 'Saving...' : 'محفوظ ہو رہا ہے...',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      )
          : Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.save_rounded, size: 22),
          const SizedBox(width: 8),
          Text(
            isEnglish ? 'Save Expense' : 'اخراجات محفوظ کریں',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}