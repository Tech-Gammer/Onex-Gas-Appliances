import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../dashboard.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  String _email = '';
  String _password = '';
  bool _isProcessing = false;
  bool _isPasswordVisible = false;
  bool _rememberMe = false;

  void _login() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() => _isProcessing = true);
      try {
        await _auth.signInWithEmailAndPassword(
          email: _email,
          password: _password,
        );
        final prefs = await SharedPreferences.getInstance();
        if (_rememberMe) {
          await prefs.setBool('remember_me', true);
          await prefs.setString('email', _email);
          await prefs.setString('password', _password);
          await prefs.setInt('last_login_time', DateTime.now().millisecondsSinceEpoch);
        } else {
          await prefs.setBool('remember_me', false);
          await prefs.remove('email');
          await prefs.remove('password');
          await prefs.remove('last_login_time');
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => Dashboard()),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed: ${e.toString().split('] ').last}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      } finally {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  void _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final lastLoginTime = prefs.getInt('last_login_time');
    final currentTime = DateTime.now().millisecondsSinceEpoch;

    // Clear credentials if it's been more than 30 days since last login
    if (lastLoginTime != null && (currentTime - lastLoginTime) > 30 * 24 * 60 * 60 * 1000) {
      await prefs.setBool('remember_me', false);
      await prefs.remove('email');
      await prefs.remove('password');
      await prefs.remove('last_login_time');
    }

    setState(() {
      _rememberMe = prefs.getBool('remember_me') ?? false;
      if (_rememberMe) {
        _email = prefs.getString('email') ?? '';
        _password = prefs.getString('password') ?? '';
      }
    });
  }


  @override
  void dispose() {
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 600;
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: 500),
          padding: EdgeInsets.all(isWeb ? 40 : 24),
          child: SingleChildScrollView(
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: EdgeInsets.all(isWeb ? 40 : 24),
                child: AutofillGroup(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/images/logo.png',
                          height: isWeb ? 150 : 120,
                          fit: BoxFit.contain,
                        ),
                        SizedBox(height: 30),
                        Text(
                          'Welcome Back',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.primaryColor,
                          ),
                        ),
                        SizedBox(height: 20),
                        TextFormField(
                          initialValue: _email,
                          autofillHints: [AutofillHints.email],
                          focusNode: _emailFocusNode,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                  color: theme.primaryColor,
                                  width: 2),
                            ),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          onSaved: (value) => _email = value!.trim(),
                          validator: (value) => value!.contains('@')
                              ? null
                              : 'Please enter a valid email',
                        ),
                        SizedBox(height: 20),
                        TextFormField(
                          initialValue: _password,
                          autofillHints: [AutofillHints.password],
                          focusNode: _passwordFocusNode,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: Colors.grey[600],
                              ),
                              onPressed: () => setState(
                                      () => _isPasswordVisible = !_isPasswordVisible),
                            ),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                  color: theme.primaryColor,
                                  width: 2),
                            ),
                          ),
                          obscureText: !_isPasswordVisible,
                          onSaved: (value) => _password = value!.trim(),
                          validator: (value) => value!.length >= 6
                              ? null
                              : 'Minimum 6 characters required',
                        ),
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              onChanged: (value) {
                                setState(() {
                                  _rememberMe = value!;
                                });
                              },
                            ),
                            Text("Remember Me"),
                          ],
                        ),
                        SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isProcessing ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange[300],
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              elevation: 3,
                            ),
                            child: _isProcessing
                                ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                                : Text(
                              'LOGIN',
                              style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2),
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}