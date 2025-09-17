import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/sale.dart';
import '../services/supabase_service.dart';

class SalesProvider with ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();
  List<Sale> _sales = [];
  bool _isLoading = false;

  List<Sale> get sales => _sales;
  bool get isLoading => _isLoading;

  List<Sale> getSalesByOrganization(String organizationId) {
    return _sales.where((sale) => sale.organizationId == organizationId).toList();
  }

  double getTotalRevenue(String organizationId) {
    return getSalesByOrganization(organizationId)
        .where((sale) => sale.status == SaleStatus.delivered)
        .fold(0.0, (sum, sale) => sum + sale.totalAmount);
  }

  Future<void> loadSales() async {
    _isLoading = true;
    notifyListeners();

    try {
      _sales = await _supabaseService.getSales();
    } catch (e) {
      print('Error loading sales: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createSale({
    required String organizationId,
    required String customerId,
    required String customerName,
    required String customerEmail,
    required List<SaleItem> items,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final uuid = const Uuid();
      final now = DateTime.now();
      final totalAmount = items.fold(0.0, (sum, item) => sum + item.totalPrice);

      final sale = Sale(
        id: uuid.v4(),
        organizationId: organizationId,
        customerId: customerId,
        customerName: customerName,
        customerEmail: customerEmail,
        items: items,
        totalAmount: totalAmount,
        status: SaleStatus.pending,
        saleDate: now,
        createdAt: now,
        updatedAt: now,
      );

      await _supabaseService.createSale(sale);
      _sales.add(sale);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateSaleStatus(String saleId, SaleStatus newStatus) async {
    _isLoading = true;
    notifyListeners();

    try {
      final saleIndex = _sales.indexWhere((sale) => sale.id == saleId);
      if (saleIndex != -1) {
        final updatedSale = _sales[saleIndex].copyWith(
          status: newStatus,
          updatedAt: DateTime.now(),
        );

        await _supabaseService.updateSale(updatedSale);

        _sales[saleIndex] = updatedSale;

        _isLoading = false;
        notifyListeners();
        return true;
      }

      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteSale(String saleId) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _supabaseService.deleteSale(saleId);

      _sales.removeWhere((sale) => sale.id == saleId);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Sale? getSaleById(String saleId) {
    try {
      return _sales.firstWhere((sale) => sale.id == saleId);
    } catch (e) {
      return null;
    }
  }

  List<Sale> getSalesByStatus(String organizationId, SaleStatus status) {
    return getSalesByOrganization(organizationId)
        .where((sale) => sale.status == status)
        .toList();
  }

  List<Sale> getSalesByDateRange(String organizationId, DateTime startDate, DateTime endDate) {
    return getSalesByOrganization(organizationId)
        .where((sale) =>
          sale.saleDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
          sale.saleDate.isBefore(endDate.add(const Duration(days: 1)))
        ).toList();
  }
}