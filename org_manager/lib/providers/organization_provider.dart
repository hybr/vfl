import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/organization.dart';
import '../services/supabase_service.dart';

class OrganizationProvider with ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();
  List<Organization> _organizations = [];
  Organization? _selectedOrganization;
  bool _isLoading = false;

  List<Organization> get organizations => _organizations;
  Organization? get selectedOrganization => _selectedOrganization;
  bool get isLoading => _isLoading;

  Future<void> loadOrganizations(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _organizations = await _supabaseService.getOrganizationsByUserId(userId);
      if (_organizations.isNotEmpty && _selectedOrganization == null) {
        _selectedOrganization = _organizations.first;
      }
    } catch (e) {
      print('Error loading organizations: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createOrganization(String name, String description, String ownerId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final uuid = const Uuid();
      final now = DateTime.now();

      final organization = Organization(
        id: uuid.v4(),
        name: name,
        description: description,
        ownerId: ownerId,
        memberIds: [ownerId],
        createdAt: now,
        updatedAt: now,
      );

      await _supabaseService.createOrganization(organization);
      _organizations.add(organization);

      if (_selectedOrganization == null) {
        _selectedOrganization = organization;
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

  Future<bool> updateOrganization(Organization organization) async {
    _isLoading = true;
    notifyListeners();

    try {
      final updatedOrg = organization.copyWith(updatedAt: DateTime.now());
      await _supabaseService.updateOrganization(updatedOrg);

      final index = _organizations.indexWhere((org) => org.id == organization.id);
      if (index != -1) {
        _organizations[index] = updatedOrg;
      }

      if (_selectedOrganization?.id == organization.id) {
        _selectedOrganization = updatedOrg;
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

  Future<bool> deleteOrganization(String organizationId) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _supabaseService.deleteOrganization(organizationId);
      _organizations.removeWhere((org) => org.id == organizationId);

      if (_selectedOrganization?.id == organizationId) {
        _selectedOrganization = _organizations.isNotEmpty ? _organizations.first : null;
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

  void selectOrganization(Organization organization) {
    _selectedOrganization = organization;
    notifyListeners();
  }

  Future<bool> addMember(String organizationId, String memberId) async {
    try {
      final organization = _organizations.firstWhere((org) => org.id == organizationId);
      if (!organization.memberIds.contains(memberId)) {
        final updatedMemberIds = [...organization.memberIds, memberId];
        final updatedOrg = organization.copyWith(memberIds: updatedMemberIds);
        return await updateOrganization(updatedOrg);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> removeMember(String organizationId, String memberId) async {
    try {
      final organization = _organizations.firstWhere((org) => org.id == organizationId);
      final updatedMemberIds = organization.memberIds.where((id) => id != memberId).toList();
      final updatedOrg = organization.copyWith(memberIds: updatedMemberIds);
      return await updateOrganization(updatedOrg);
    } catch (e) {
      return false;
    }
  }
}