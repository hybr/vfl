import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/organizations/organizations_screen.dart';
import '../screens/organizations/organization_detail_screen.dart';
import '../screens/workflows/workflows_screen.dart';
import '../screens/workflows/workflow_detail_screen.dart';
import '../screens/products/products_screen.dart';
import '../screens/products/product_detail_screen.dart';
import '../screens/sales/sales_screen.dart';
import '../screens/sales/sale_detail_screen.dart';
import '../screens/rentals/rentals_screen.dart';
import '../screens/rentals/rental_detail_screen.dart';
import '../screens/profile/profile_screen.dart';

class AppRouter {
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/';
  static const String organizations = '/organizations';
  static const String organizationDetail = '/organizations/:id';
  static const String workflows = '/workflows';
  static const String workflowDetail = '/workflows/:id';
  static const String products = '/products';
  static const String productDetail = '/products/:id';
  static const String sales = '/sales';
  static const String saleDetail = '/sales/:id';
  static const String rentals = '/rentals';
  static const String rentalDetail = '/rentals/:id';
  static const String profile = '/profile';

  static GoRouter createRouter() {
    return GoRouter(
      initialLocation: login,
      redirect: (context, state) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final isAuthenticated = authProvider.isAuthenticated;
        final isOnAuthScreen = state.fullPath == login || state.fullPath == register;

        if (!isAuthenticated && !isOnAuthScreen) {
          return login;
        }
        if (isAuthenticated && isOnAuthScreen) {
          return home;
        }
        return null;
      },
      routes: [
        GoRoute(
          path: login,
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: register,
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: home,
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: organizations,
          builder: (context, state) => const OrganizationsScreen(),
        ),
        GoRoute(
          path: organizationDetail,
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return OrganizationDetailScreen(organizationId: id);
          },
        ),
        GoRoute(
          path: workflows,
          builder: (context, state) => const WorkflowsScreen(),
        ),
        GoRoute(
          path: workflowDetail,
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return WorkflowDetailScreen(workflowId: id);
          },
        ),
        GoRoute(
          path: products,
          builder: (context, state) => const ProductsScreen(),
        ),
        GoRoute(
          path: productDetail,
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return ProductDetailScreen(productId: id);
          },
        ),
        GoRoute(
          path: sales,
          builder: (context, state) => const SalesScreen(),
        ),
        GoRoute(
          path: saleDetail,
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return SaleDetailScreen(saleId: id);
          },
        ),
        GoRoute(
          path: rentals,
          builder: (context, state) => const RentalsScreen(),
        ),
        GoRoute(
          path: rentalDetail,
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return RentalDetailScreen(rentalId: id);
          },
        ),
        GoRoute(
          path: profile,
          builder: (context, state) => const ProfileScreen(),
        ),
      ],
    );
  }
}