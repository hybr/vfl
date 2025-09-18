import 'dart:convert';
import '../models/rbac.dart';

abstract class CacheService {
  Future<PermissionCheckResult?> getPermission(String cacheKey);
  Future<void> setPermission(String cacheKey, PermissionCheckResult result);
  Future<void> invalidateUserPermissions(String userId);
  Future<void> invalidatePattern(String pattern);
  Future<void> clear();
}

class MemoryCacheService implements CacheService {
  final Map<String, CacheEntry> _cache = {};
  final Duration _defaultTtl = const Duration(minutes: 5);

  @override
  Future<PermissionCheckResult?> getPermission(String cacheKey) async {
    final entry = _cache[cacheKey];
    
    if (entry == null) return null;
    
    if (entry.expiresAt.isBefore(DateTime.now())) {
      _cache.remove(cacheKey);
      return null;
    }
    
    return entry.result;
  }

  @override
  Future<void> setPermission(String cacheKey, PermissionCheckResult result) async {
    _cache[cacheKey] = CacheEntry(
      result: result,
      expiresAt: DateTime.now().add(_defaultTtl),
    );
  }

  @override
  Future<void> invalidateUserPermissions(String userId) async {
    final keysToRemove = _cache.keys
        .where((key) => key.startsWith('$userId:'))
        .toList();
    
    for (final key in keysToRemove) {
      _cache.remove(key);
    }
  }

  @override
  Future<void> invalidatePattern(String pattern) async {
    final regex = RegExp(pattern.replaceAll('*', '.*'));
    final keysToRemove = _cache.keys
        .where((key) => regex.hasMatch(key))
        .toList();
    
    for (final key in keysToRemove) {
      _cache.remove(key);
    }
  }

  @override
  Future<void> clear() async {
    _cache.clear();
  }

  void _cleanup() {
    final now = DateTime.now();
    final expiredKeys = _cache.entries
        .where((entry) => entry.value.expiresAt.isBefore(now))
        .map((entry) => entry.key)
        .toList();
    
    for (final key in expiredKeys) {
      _cache.remove(key);
    }
  }

  void startCleanupTimer() {
    Timer.periodic(const Duration(minutes: 1), (_) => _cleanup());
  }
}

class CacheEntry {
  final PermissionCheckResult result;
  final DateTime expiresAt;

  CacheEntry({
    required this.result,
    required this.expiresAt,
  });
}

import 'dart:async';