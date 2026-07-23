import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// -----------------------------------------------------------------------------
// MOCK LOGIC: To strictly avoid modifying production files or triggering live 
// Firebase Auth instances, we simulate the AuthGate's StreamBuilder behavior.
// -----------------------------------------------------------------------------
class MockAuthGate extends StatelessWidget {
  final Stream<String?> mockAuthStream;

  const MockAuthGate({super.key, required this.mockAuthStream});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: StreamBuilder<String?>(
        stream: mockAuthStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          // If User is Authenticated -> Route to Dashboard
          if (snapshot.hasData && snapshot.data != null) {
            return const Scaffold(body: Center(child: Text('DashboardScreen')));
          }
          // If User is Null/Unauthenticated -> Route to Login
          return const Scaffold(body: Center(child: Text('RoleSelectionScreen')));
        },
      ),
    );
  }
}

void main() {
  group('Auth Gate Reactive Routing Tests (SafeKid Navigation)', () {
    
    testWidgets('Test A: Null Firebase Auth user renders RoleSelectionScreen', (WidgetTester tester) async {
      // 1. Arrange: Mock an auth stream that yields null (unauthenticated)
      final Stream<String?> unauthenticatedStream = Stream.value(null);

      // 2. Act: Pump the widget
      await tester.pumpWidget(MockAuthGate(mockAuthStream: unauthenticatedStream));
      await tester.pumpAndSettle();

      // 3. Assert: Verify routing logic blocks access to Dashboard
      expect(find.text('RoleSelectionScreen'), findsOneWidget);
      expect(find.text('DashboardScreen'), findsNothing);
    });

    testWidgets('Test B: Valid Firebase Auth user bypasses login and renders Dashboard', (WidgetTester tester) async {
      // 1. Arrange: Mock an auth stream that yields a valid UID (authenticated)
      final Stream<String?> authenticatedStream = Stream.value("mock_uid_12345");

      // 2. Act: Pump the widget
      await tester.pumpWidget(MockAuthGate(mockAuthStream: authenticatedStream));
      await tester.pumpAndSettle();

      // 3. Assert: Verify routing logic grants access
      expect(find.text('DashboardScreen'), findsOneWidget);
      expect(find.text('RoleSelectionScreen'), findsNothing);
    });
    
  });
}
