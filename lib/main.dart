import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/department_provider.dart';
import 'providers/vendor_provider.dart';
import 'providers/rfq_provider.dart';
import 'providers/order_provider.dart';
import 'providers/notification_provider.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/rfq_create_screen.dart';
import 'screens/my_rfqs_screen.dart';
import 'screens/approval_dashboard_screen.dart';
import 'screens/orders_dashboard_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/home_screen.dart' show homeRouteObserver;

void main() {
  runApp(const SoliflexApp());
}

class SoliflexApp extends StatelessWidget {
  const SoliflexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DepartmentProvider()),
        ChangeNotifierProvider(create: (_) => VendorProvider()),
        ChangeNotifierProvider(create: (_) => RFQProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          // Determine initial route based on auth state
          final initialRoute = authProvider.isAuthenticated ? '/home' : '/login';
          
          return MaterialApp(
            title: 'Soliflex Packaging',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            navigatorObservers: [homeRouteObserver],
            initialRoute: initialRoute,
            routes: {
              '/login': (context) => const LoginScreen(),
              '/register': (context) => const RegisterScreen(),
              '/home': (context) => const HomeScreen(),
              '/rfq/create': (context) => const RFQCreateScreen(),
              '/orders': (context) => const OrdersDashboardScreen(),
              '/approvals': (context) => const ApprovalDashboardScreen(),
              '/notifications': (context) => const NotificationsScreen(),
            },
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(1.0),
                ),
                child: child!,
              );
            },
          );
        },
      ),
    );
  }
}

