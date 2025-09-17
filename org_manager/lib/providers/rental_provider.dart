import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/rental.dart';
import '../services/supabase_service.dart';

class RentalProvider with ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();
  List<Rental> _rentals = [];
  bool _isLoading = false;

  List<Rental> get rentals => _rentals;
  bool get isLoading => _isLoading;

  List<Rental> getRentalsByOrganization(String organizationId) {
    return _rentals.where((rental) => rental.organizationId == organizationId).toList();
  }

  double getTotalRentalRevenue(String organizationId) {
    return getRentalsByOrganization(organizationId)
        .where((rental) => rental.status == RentalStatus.returned)
        .fold(0.0, (sum, rental) => sum + rental.totalAmount);
  }

  List<Rental> getActiveRentals(String organizationId) {
    return getRentalsByOrganization(organizationId)
        .where((rental) => rental.status == RentalStatus.active)
        .toList();
  }

  List<Rental> getOverdueRentals(String organizationId) {
    final now = DateTime.now();
    return getRentalsByOrganization(organizationId)
        .where((rental) =>
          rental.status == RentalStatus.active &&
          rental.endDate.isBefore(now)
        ).toList();
  }

  Future<void> loadRentals() async {
    _isLoading = true;
    notifyListeners();

    try {
      _rentals = await _supabaseService.getRentals();
    } catch (e) {
      print('Error loading rentals: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createRental({
    required String organizationId,
    required String customerId,
    required String customerName,
    required String customerEmail,
    required List<RentalItem> items,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final uuid = const Uuid();
      final now = DateTime.now();
      final totalAmount = items.fold(0.0, (sum, item) => sum + item.totalPrice);

      final rental = Rental(
        id: uuid.v4(),
        organizationId: organizationId,
        customerId: customerId,
        customerName: customerName,
        customerEmail: customerEmail,
        items: items,
        totalAmount: totalAmount,
        status: RentalStatus.pending,
        startDate: startDate,
        endDate: endDate,
        createdAt: now,
        updatedAt: now,
      );

      await _supabaseService.createRental(rental);
      _rentals.add(rental);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateRentalStatus(String rentalId, RentalStatus newStatus) async {
    _isLoading = true;
    notifyListeners();

    try {
      final rentalIndex = _rentals.indexWhere((rental) => rental.id == rentalId);
      if (rentalIndex != -1) {
        final updatedRental = _rentals[rentalIndex].copyWith(
          status: newStatus,
          returnDate: newStatus == RentalStatus.returned ? DateTime.now() : null,
          updatedAt: DateTime.now(),
        );

        await _supabaseService.updateRental(updatedRental);

        _rentals[rentalIndex] = updatedRental;

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

  Future<bool> extendRental(String rentalId, DateTime newEndDate) async {
    _isLoading = true;
    notifyListeners();

    try {
      final rentalIndex = _rentals.indexWhere((rental) => rental.id == rentalId);
      if (rentalIndex != -1) {
        final rental = _rentals[rentalIndex];
        final additionalDays = newEndDate.difference(rental.endDate).inDays;
        final additionalCost = rental.items.fold(0.0, (sum, item) =>
          sum + (item.dailyRate * item.quantity * additionalDays)
        );

        final updatedRental = rental.copyWith(
          endDate: newEndDate,
          totalAmount: rental.totalAmount + additionalCost,
          updatedAt: DateTime.now(),
        );

        await _supabaseService.updateRental(updatedRental);

        _rentals[rentalIndex] = updatedRental;

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

  Future<bool> deleteRental(String rentalId) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _supabaseService.deleteRental(rentalId);

      _rentals.removeWhere((rental) => rental.id == rentalId);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Rental? getRentalById(String rentalId) {
    try {
      return _rentals.firstWhere((rental) => rental.id == rentalId);
    } catch (e) {
      return null;
    }
  }

  List<Rental> getRentalsByStatus(String organizationId, RentalStatus status) {
    return getRentalsByOrganization(organizationId)
        .where((rental) => rental.status == status)
        .toList();
  }

  List<Rental> getRentalsByDateRange(String organizationId, DateTime startDate, DateTime endDate) {
    return getRentalsByOrganization(organizationId)
        .where((rental) =>
          rental.startDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
          rental.startDate.isBefore(endDate.add(const Duration(days: 1)))
        ).toList();
  }
}