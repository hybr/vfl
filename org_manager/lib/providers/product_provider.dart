import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/product.dart';
import '../services/supabase_service.dart';

class ProductProvider with ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();
  List<Product> _products = [];
  bool _isLoading = false;

  List<Product> get products => _products;
  bool get isLoading => _isLoading;

  List<Product> getProductsByOrganization(String organizationId) {
    return _products.where((product) => product.organizationId == organizationId).toList();
  }

  List<Product> getAvailableForSale(String organizationId) {
    return _products.where((product) =>
      product.organizationId == organizationId &&
      product.isAvailableForSale &&
      product.quantityAvailable > 0
    ).toList();
  }

  List<Product> getAvailableForRent(String organizationId) {
    return _products.where((product) =>
      product.organizationId == organizationId &&
      product.isAvailableForRent &&
      product.quantityAvailable > 0
    ).toList();
  }

  Future<void> loadProducts() async {
    _isLoading = true;
    notifyListeners();

    try {
      _products = await _supabaseService.getProducts();
    } catch (e) {
      print('Error loading products: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createProduct({
    required String name,
    required String description,
    required ProductType type,
    required double price,
    String? imageUrl,
    required String organizationId,
    required bool isAvailableForSale,
    required bool isAvailableForRent,
    double? rentPricePerDay,
    required int quantityAvailable,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final uuid = const Uuid();
      final now = DateTime.now();

      final product = Product(
        id: uuid.v4(),
        name: name,
        description: description,
        type: type,
        price: price,
        imageUrl: imageUrl,
        organizationId: organizationId,
        isAvailableForSale: isAvailableForSale,
        isAvailableForRent: isAvailableForRent,
        rentPricePerDay: rentPricePerDay,
        quantityAvailable: quantityAvailable,
        createdAt: now,
        updatedAt: now,
      );

      await _supabaseService.createProduct(product);
      _products.add(product);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProduct(Product product) async {
    _isLoading = true;
    notifyListeners();

    try {
      final updatedProduct = product.copyWith(updatedAt: DateTime.now());

      await _supabaseService.updateProduct(updatedProduct);

      final index = _products.indexWhere((p) => p.id == product.id);
      if (index != -1) {
        _products[index] = updatedProduct;
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteProduct(String productId) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _supabaseService.deleteProduct(productId);

      _products.removeWhere((product) => product.id == productId);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateQuantity(String productId, int newQuantity) async {
    try {
      final productIndex = _products.indexWhere((p) => p.id == productId);
      if (productIndex != -1) {
        final updatedProduct = _products[productIndex].copyWith(
          quantityAvailable: newQuantity,
          updatedAt: DateTime.now(),
        );
        return await updateProduct(updatedProduct);
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Product? getProductById(String productId) {
    try {
      return _products.firstWhere((product) => product.id == productId);
    } catch (e) {
      return null;
    }
  }
}