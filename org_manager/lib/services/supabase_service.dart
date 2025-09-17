import '../models/user.dart';
import '../models/organization.dart';
import '../models/workflow.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/rental.dart';
import '../utils/supabase_config.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  // Organizations
  Future<List<Organization>> getOrganizationsByUserId(String userId) async {
    try {
      final response = await SupabaseConfig.from('organizations')
          .select()
          .or('owner_id.eq.$userId,member_ids.cs.{$userId}');

      return (response as List).map((org) => Organization.fromJson({
        'id': org['id'],
        'name': org['name'],
        'description': org['description'],
        'logoUrl': org['logo_url'],
        'ownerId': org['owner_id'],
        'memberIds': (org['member_ids'] as List?)?.cast<String>() ?? [],
        'createdAt': org['created_at'],
        'updatedAt': org['updated_at'],
      })).toList();
    } catch (e) {
      print('Error fetching organizations: $e');
      return [];
    }
  }

  Future<bool> createOrganization(Organization organization) async {
    try {
      await SupabaseConfig.from('organizations').insert({
        'id': organization.id,
        'name': organization.name,
        'description': organization.description,
        'logo_url': organization.logoUrl,
        'owner_id': organization.ownerId,
        'member_ids': organization.memberIds,
        'created_at': organization.createdAt.toIso8601String(),
        'updated_at': organization.updatedAt.toIso8601String(),
      });
      return true;
    } catch (e) {
      print('Error creating organization: $e');
      return false;
    }
  }

  Future<bool> updateOrganization(Organization organization) async {
    try {
      await SupabaseConfig.from('organizations')
          .update({
            'name': organization.name,
            'description': organization.description,
            'logo_url': organization.logoUrl,
            'member_ids': organization.memberIds,
            'updated_at': organization.updatedAt.toIso8601String(),
          })
          .eq('id', organization.id);
      return true;
    } catch (e) {
      print('Error updating organization: $e');
      return false;
    }
  }

  Future<bool> deleteOrganization(String organizationId) async {
    try {
      await SupabaseConfig.from('organizations').delete().eq('id', organizationId);
      return true;
    } catch (e) {
      print('Error deleting organization: $e');
      return false;
    }
  }

  // Products
  Future<List<Product>> getProducts() async {
    try {
      final response = await SupabaseConfig.from('products').select();

      return (response as List).map((product) => Product.fromJson({
        'id': product['id'],
        'name': product['name'],
        'description': product['description'],
        'type': product['type'],
        'price': product['price']?.toDouble() ?? 0.0,
        'imageUrl': product['image_url'],
        'organizationId': product['organization_id'],
        'isAvailableForSale': product['is_available_for_sale'] ?? false,
        'isAvailableForRent': product['is_available_for_rent'] ?? false,
        'rentPricePerDay': product['rent_price_per_day']?.toDouble(),
        'quantityAvailable': product['quantity_available'] ?? 0,
        'createdAt': product['created_at'],
        'updatedAt': product['updated_at'],
      })).toList();
    } catch (e) {
      print('Error fetching products: $e');
      return [];
    }
  }

  Future<bool> createProduct(Product product) async {
    try {
      await SupabaseConfig.from('products').insert({
        'id': product.id,
        'name': product.name,
        'description': product.description,
        'type': product.type.toString().split('.').last,
        'price': product.price,
        'image_url': product.imageUrl,
        'organization_id': product.organizationId,
        'is_available_for_sale': product.isAvailableForSale,
        'is_available_for_rent': product.isAvailableForRent,
        'rent_price_per_day': product.rentPricePerDay,
        'quantity_available': product.quantityAvailable,
        'created_at': product.createdAt.toIso8601String(),
        'updated_at': product.updatedAt.toIso8601String(),
      });
      return true;
    } catch (e) {
      print('Error creating product: $e');
      return false;
    }
  }

  Future<bool> updateProduct(Product product) async {
    try {
      await SupabaseConfig.from('products')
          .update({
            'name': product.name,
            'description': product.description,
            'type': product.type.toString().split('.').last,
            'price': product.price,
            'image_url': product.imageUrl,
            'is_available_for_sale': product.isAvailableForSale,
            'is_available_for_rent': product.isAvailableForRent,
            'rent_price_per_day': product.rentPricePerDay,
            'quantity_available': product.quantityAvailable,
            'updated_at': product.updatedAt.toIso8601String(),
          })
          .eq('id', product.id);
      return true;
    } catch (e) {
      print('Error updating product: $e');
      return false;
    }
  }

  Future<bool> deleteProduct(String productId) async {
    try {
      await SupabaseConfig.from('products').delete().eq('id', productId);
      return true;
    } catch (e) {
      print('Error deleting product: $e');
      return false;
    }
  }

  // Workflows
  Future<List<Workflow>> getWorkflows() async {
    try {
      final response = await SupabaseConfig.from('workflows').select();

      return (response as List).map((workflow) => Workflow.fromJson({
        'id': workflow['id'],
        'name': workflow['name'],
        'description': workflow['description'],
        'organizationId': workflow['organization_id'],
        'createdBy': workflow['created_by'],
        'status': workflow['status'],
        'tasks': workflow['tasks'] ?? [],
        'createdAt': workflow['created_at'],
        'updatedAt': workflow['updated_at'],
      })).toList();
    } catch (e) {
      print('Error fetching workflows: $e');
      return [];
    }
  }

  Future<bool> createWorkflow(Workflow workflow) async {
    try {
      await SupabaseConfig.from('workflows').insert({
        'id': workflow.id,
        'name': workflow.name,
        'description': workflow.description,
        'organization_id': workflow.organizationId,
        'created_by': workflow.createdBy,
        'status': workflow.status.toString().split('.').last,
        'tasks': workflow.tasks.map((task) => task.toJson()).toList(),
        'created_at': workflow.createdAt.toIso8601String(),
        'updated_at': workflow.updatedAt.toIso8601String(),
      });
      return true;
    } catch (e) {
      print('Error creating workflow: $e');
      return false;
    }
  }

  Future<bool> updateWorkflow(Workflow workflow) async {
    try {
      await SupabaseConfig.from('workflows')
          .update({
            'name': workflow.name,
            'description': workflow.description,
            'status': workflow.status.toString().split('.').last,
            'tasks': workflow.tasks.map((task) => task.toJson()).toList(),
            'updated_at': workflow.updatedAt.toIso8601String(),
          })
          .eq('id', workflow.id);
      return true;
    } catch (e) {
      print('Error updating workflow: $e');
      return false;
    }
  }

  Future<bool> deleteWorkflow(String workflowId) async {
    try {
      await SupabaseConfig.from('workflows').delete().eq('id', workflowId);
      return true;
    } catch (e) {
      print('Error deleting workflow: $e');
      return false;
    }
  }

  // Sales
  Future<List<Sale>> getSales() async {
    try {
      final response = await SupabaseConfig.from('sales').select();

      return (response as List).map((sale) => Sale.fromJson({
        'id': sale['id'],
        'organizationId': sale['organization_id'],
        'customerId': sale['customer_id'],
        'customerName': sale['customer_name'],
        'customerEmail': sale['customer_email'],
        'items': sale['items'] ?? [],
        'totalAmount': sale['total_amount']?.toDouble() ?? 0.0,
        'status': sale['status'],
        'saleDate': sale['sale_date'],
        'createdAt': sale['created_at'],
        'updatedAt': sale['updated_at'],
      })).toList();
    } catch (e) {
      print('Error fetching sales: $e');
      return [];
    }
  }

  Future<bool> createSale(Sale sale) async {
    try {
      await SupabaseConfig.from('sales').insert({
        'id': sale.id,
        'organization_id': sale.organizationId,
        'customer_id': sale.customerId,
        'customer_name': sale.customerName,
        'customer_email': sale.customerEmail,
        'items': sale.items.map((item) => item.toJson()).toList(),
        'total_amount': sale.totalAmount,
        'status': sale.status.toString().split('.').last,
        'sale_date': sale.saleDate.toIso8601String(),
        'created_at': sale.createdAt.toIso8601String(),
        'updated_at': sale.updatedAt.toIso8601String(),
      });
      return true;
    } catch (e) {
      print('Error creating sale: $e');
      return false;
    }
  }

  Future<bool> updateSale(Sale sale) async {
    try {
      await SupabaseConfig.from('sales')
          .update({
            'status': sale.status.toString().split('.').last,
            'updated_at': sale.updatedAt.toIso8601String(),
          })
          .eq('id', sale.id);
      return true;
    } catch (e) {
      print('Error updating sale: $e');
      return false;
    }
  }

  Future<bool> deleteSale(String saleId) async {
    try {
      await SupabaseConfig.from('sales').delete().eq('id', saleId);
      return true;
    } catch (e) {
      print('Error deleting sale: $e');
      return false;
    }
  }

  // Rentals
  Future<List<Rental>> getRentals() async {
    try {
      final response = await SupabaseConfig.from('rentals').select();

      return (response as List).map((rental) => Rental.fromJson({
        'id': rental['id'],
        'organizationId': rental['organization_id'],
        'customerId': rental['customer_id'],
        'customerName': rental['customer_name'],
        'customerEmail': rental['customer_email'],
        'items': rental['items'] ?? [],
        'totalAmount': rental['total_amount']?.toDouble() ?? 0.0,
        'status': rental['status'],
        'startDate': rental['start_date'],
        'endDate': rental['end_date'],
        'returnDate': rental['return_date'],
        'createdAt': rental['created_at'],
        'updatedAt': rental['updated_at'],
      })).toList();
    } catch (e) {
      print('Error fetching rentals: $e');
      return [];
    }
  }

  Future<bool> createRental(Rental rental) async {
    try {
      await SupabaseConfig.from('rentals').insert({
        'id': rental.id,
        'organization_id': rental.organizationId,
        'customer_id': rental.customerId,
        'customer_name': rental.customerName,
        'customer_email': rental.customerEmail,
        'items': rental.items.map((item) => item.toJson()).toList(),
        'total_amount': rental.totalAmount,
        'status': rental.status.toString().split('.').last,
        'start_date': rental.startDate.toIso8601String(),
        'end_date': rental.endDate.toIso8601String(),
        'return_date': rental.returnDate?.toIso8601String(),
        'created_at': rental.createdAt.toIso8601String(),
        'updated_at': rental.updatedAt.toIso8601String(),
      });
      return true;
    } catch (e) {
      print('Error creating rental: $e');
      return false;
    }
  }

  Future<bool> updateRental(Rental rental) async {
    try {
      await SupabaseConfig.from('rentals')
          .update({
            'status': rental.status.toString().split('.').last,
            'return_date': rental.returnDate?.toIso8601String(),
            'updated_at': rental.updatedAt.toIso8601String(),
          })
          .eq('id', rental.id);
      return true;
    } catch (e) {
      print('Error updating rental: $e');
      return false;
    }
  }

  Future<bool> deleteRental(String rentalId) async {
    try {
      await SupabaseConfig.from('rentals').delete().eq('id', rentalId);
      return true;
    } catch (e) {
      print('Error deleting rental: $e');
      return false;
    }
  }
}