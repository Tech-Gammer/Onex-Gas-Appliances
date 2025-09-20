import 'package:flutter/material.dart';

class DomainExpiredPage extends StatelessWidget {
  const DomainExpiredPage({super.key});

  // Define some consistent styling (optional, can be part of your app's theme)
  static const Color pageBackgroundColor = Color(0xFFF8F9FA); // A light grey
  static const Color primaryTextColor = Color(0xFF212529); // Dark grey for text
  static const Color secondaryTextColor = Color(0xFF6C757D); // Lighter grey for subtext
  static const Color iconColor = Colors.orangeAccent; // Color for the warning icon

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBackgroundColor,
      appBar: AppBar(
        title: const Text('Service Unavailable', style: TextStyle(color: primaryTextColor)),
        backgroundColor: Colors.white, // Or your app's standard AppBar color
        elevation: 1.0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: primaryTextColor), // For back button if navigated to
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Icon(
                Icons.error_outline, // A warning or error icon
                color: iconColor,
                size: 80.0,
              ),
              const SizedBox(height: 24.0),
              Text(
                'Service Temporarily Unavailable',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26.0,
                  fontWeight: FontWeight.bold,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 12.0),
              Text(
                'We apologize for the inconvenience. Our service is currently down due to a domain or subscription issue.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16.0,
                  color: secondaryTextColor,
                  height: 1.5, // Line height for better readability
                ),
              ),
              const SizedBox(height: 24.0),
              Text(
                'Our team is working to resolve this as quickly as possible.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16.0,
                  color: secondaryTextColor,
                ),
              ),
              const SizedBox(height: 32.0),

              // Optional: Contact Information or Link
              // You can uncomment and modify this section if needed.
              /*
              Text(
                'If you are the administrator, please check your domain registration or service subscription.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.0,
                  color: Colors.blueGrey[700],
                ),
              ),
              const SizedBox(height: 16.0),
              ElevatedButton.icon(
                icon: Icon(Icons.contact_support_outlined),
                label: Text('Contact Support'),
                onPressed: () {
                  // TODO: Implement contact support action (e.g., open email, launch URL)
                  // For example: launchUrl(Uri.parse('mailto:support@example.com'));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Contact functionality not yet implemented.')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor, // Use your app's primary color
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              */

              // Optional: A button to attempt a refresh or go back
              // This might not be useful if the core domain is down.
              /*
              const SizedBox(height: 16.0),
              OutlinedButton(
                onPressed: () {
                  // You might try to re-check a status or simply pop the page
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
                child: Text('Try Again or Go Back'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryTextColor,
                  side: BorderSide(color: primaryTextColor.withOpacity(0.5)),
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              */
            ],
          ),
        ),
      ),
    );
  }
}
