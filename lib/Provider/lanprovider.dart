import 'package:flutter/material.dart';

class LanguageProvider with ChangeNotifier {
  bool _isEnglish = true;

  bool get isEnglish => _isEnglish;

  void toggleLanguage() {
    _isEnglish = !_isEnglish;
    notifyListeners();
  }
  // Method to get the correct font family based on the language
  String get fontFamily {
    return _isEnglish ? 'Roboto' : 'JameelNoori';  // Default font for English is 'Roboto'
  }
}
