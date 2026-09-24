import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/screens/signup_screen.dart';

void main() {
  testWidgets('Login screen has Email, Password fields, Login button, Forgot link, and Register link', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Verify title & button text
    expect(find.text('Login'), findsWidgets);

    // Verify fields
    expect(find.widgetWithText(TextFormField, 'Email ID'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);

    // Verify buttons and links
    expect(find.byKey(const Key('login_button')), findsOneWidget);
    expect(find.text('Forgot?'), findsOneWidget);
    expect(find.text('Register'), findsOneWidget);
    expect(find.text('New to iThickLogistics? '), findsOneWidget);
  });

  testWidgets('Navigation from Login to Sign Up screen displays all Sign Up fields and buttons', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Tap on Register link
    await tester.ensureVisible(find.text('Register'));
    await tester.tap(find.text('Register'));
    await tester.pumpAndSettle();

    // Verify Sign Up screen components
    expect(find.byType(SignUpScreen), findsOneWidget);
    expect(find.text('Sign up'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Full name'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Employee Code / Company name'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Email ID'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Confirm Password'), findsOneWidget);

    // Verify Sign Up buttons and links
    expect(find.byKey(const Key('signup_button')), findsOneWidget);
    expect(find.text('Already have an account? '), findsOneWidget);
    expect(find.text('Login'), findsWidgets);
  });

  testWidgets('Forgot link opens reset dialog', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Tap Forgot?
    await tester.ensureVisible(find.text('Forgot?'));
    await tester.tap(find.text('Forgot?'));
    await tester.pumpAndSettle();

    // Verify dialog appears
    expect(find.text('Reset Password'), findsOneWidget);
    expect(find.text('Send Link'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });
}
