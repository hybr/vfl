import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user.dart';
import '../models/organization.dart';
import '../models/workflow.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/rental.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'org_manager.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        email TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        profileImageUrl TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE organizations (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        logoUrl TEXT,
        ownerId TEXT NOT NULL,
        memberIds TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        FOREIGN KEY (ownerId) REFERENCES users (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE workflows (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        organizationId TEXT NOT NULL,
        createdBy TEXT NOT NULL,
        status TEXT NOT NULL,
        tasks TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        FOREIGN KEY (organizationId) REFERENCES organizations (id),
        FOREIGN KEY (createdBy) REFERENCES users (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        type TEXT NOT NULL,
        price REAL NOT NULL,
        imageUrl TEXT,
        organizationId TEXT NOT NULL,
        isAvailableForSale INTEGER NOT NULL,
        isAvailableForRent INTEGER NOT NULL,
        rentPricePerDay REAL,
        quantityAvailable INTEGER NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        FOREIGN KEY (organizationId) REFERENCES organizations (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE sales (
        id TEXT PRIMARY KEY,
        organizationId TEXT NOT NULL,
        customerId TEXT NOT NULL,
        customerName TEXT NOT NULL,
        customerEmail TEXT NOT NULL,
        items TEXT NOT NULL,
        totalAmount REAL NOT NULL,
        status TEXT NOT NULL,
        saleDate TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        FOREIGN KEY (organizationId) REFERENCES organizations (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE rentals (
        id TEXT PRIMARY KEY,
        organizationId TEXT NOT NULL,
        customerId TEXT NOT NULL,
        customerName TEXT NOT NULL,
        customerEmail TEXT NOT NULL,
        items TEXT NOT NULL,
        totalAmount REAL NOT NULL,
        status TEXT NOT NULL,
        startDate TEXT NOT NULL,
        endDate TEXT NOT NULL,
        returnDate TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        FOREIGN KEY (organizationId) REFERENCES organizations (id)
      )
    ''');
  }

  Future<int> insertUser(User user) async {
    final db = await database;
    return await db.insert('users', user.toJson());
  }

  Future<List<User>> getUsers() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('users');
    return List.generate(maps.length, (i) => User.fromJson(maps[i]));
  }

  Future<User?> getUserById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return User.fromJson(maps.first);
    }
    return null;
  }

  Future<int> updateUser(User user) async {
    final db = await database;
    return await db.update(
      'users',
      user.toJson(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  Future<int> deleteUser(String id) async {
    final db = await database;
    return await db.delete(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> insertOrganization(Organization organization) async {
    final db = await database;
    final orgJson = organization.toJson();
    orgJson['memberIds'] = orgJson['memberIds'].join(',');
    return await db.insert('organizations', orgJson);
  }

  Future<List<Organization>> getOrganizations() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('organizations');
    return List.generate(maps.length, (i) {
      final map = Map<String, dynamic>.from(maps[i]);
      map['memberIds'] = (map['memberIds'] as String).split(',').where((id) => id.isNotEmpty).toList();
      return Organization.fromJson(map);
    });
  }

  Future<Organization?> getOrganizationById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'organizations',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      final map = Map<String, dynamic>.from(maps.first);
      map['memberIds'] = (map['memberIds'] as String).split(',').where((id) => id.isNotEmpty).toList();
      return Organization.fromJson(map);
    }
    return null;
  }

  Future<List<Organization>> getOrganizationsByUserId(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'organizations',
      where: 'ownerId = ? OR memberIds LIKE ?',
      whereArgs: [userId, '%$userId%'],
    );
    return List.generate(maps.length, (i) {
      final map = Map<String, dynamic>.from(maps[i]);
      map['memberIds'] = (map['memberIds'] as String).split(',').where((id) => id.isNotEmpty).toList();
      return Organization.fromJson(map);
    });
  }

  Future<int> updateOrganization(Organization organization) async {
    final db = await database;
    final orgJson = organization.toJson();
    orgJson['memberIds'] = orgJson['memberIds'].join(',');
    return await db.update(
      'organizations',
      orgJson,
      where: 'id = ?',
      whereArgs: [organization.id],
    );
  }

  Future<int> deleteOrganization(String id) async {
    final db = await database;
    return await db.delete(
      'organizations',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}