import 'package:drift/drift.dart';
import '../core/utils/password_utils.dart';
import '../data/database/app_database.dart';
import '../core/utils/sync_identity.dart';

class AuthService {
  final AppDatabase db;
  AuthService(this.db);

  Future<User?> login(String username, String password) async {
    final user = await (db.select(db.users)
          ..where((u) => u.username.equals(username.trim())))
        .getSingleOrNull();

    if (user == null || user.isActive == 0) return null;
    if (!PasswordUtils.verify(password, user.passwordHash)) return null;

    await (db.update(db.users)..where((u) => u.id.equals(user.id))).write(
      UsersCompanion(lastLogin: Value(DateTime.now()), updatedAt: Value(DateTime.now())),
    );
    return user;
  }

  Future<bool> createUser({
    required String username,
    required String password,
    required String fullName,
    required String role,
    required int createdById,
  }) async {
    if (username.trim().toLowerCase() == 'root@zeynepc.arkas') return false;

    final exists = await (db.select(db.users)
          ..where((u) => u.username.equals(username.trim())))
        .getSingleOrNull();
    if (exists != null) return false;

    final canManage = ['ROOT', 'MASTER', 'SECOND', 'REIS'].contains(role);

    await db.into(db.users).insert(UsersCompanion.insert(
          syncId: Value(SyncIdentity.newId()),
          username: username.trim(),
          passwordHash: PasswordUtils.hash(password),
          fullName: fullName.trim(),
          role: role,
          isActive: const Value(1),
          canManageUsers: Value(canManage ? 1 : 0),
          createdBy: Value(createdById),
        ));
    return true;
  }

  Future<void> setUserActive(int userId, bool isActive) async {
    final user = await (db.select(db.users)..where((u) => u.id.equals(userId)))
        .getSingleOrNull();
    if (user == null || user.username == 'root@zeynepc.arkas') return;

    await (db.update(db.users)..where((u) => u.id.equals(userId))).write(
      UsersCompanion(isActive: Value(isActive ? 1 : 0), updatedAt: Value(DateTime.now())),
    );
  }

  Future<bool> changePassword({
    required int userId,
    required String oldPassword,
    required String newPassword,
  }) async {
    final user = await (db.select(db.users)..where((u) => u.id.equals(userId)))
        .getSingleOrNull();
    if (user == null) return false;
    if (!PasswordUtils.verify(oldPassword, user.passwordHash)) return false;

    await (db.update(db.users)..where((u) => u.id.equals(userId))).write(
      UsersCompanion(passwordHash: Value(PasswordUtils.hash(newPassword)), updatedAt: Value(DateTime.now())),
    );
    return true;
  }
}
