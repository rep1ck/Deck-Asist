import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';

class UserManagementScreen extends ConsumerWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider)!;
    final canManage =
        ['ROOT', 'MASTER', 'SECOND', 'REIS'].contains(currentUser.role);

    if (!canManage) {
      return const Scaffold(
        body: Center(child: Text('Bu sayfaya erişim yetkiniz yok')),
      );
    }

    final usersAsync = ref.watch(usersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kullanıcı Yönetimi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDialog(context, ref),
          ),
        ],
      ),
      body: usersAsync.when(
        data: (users) {
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              final isRoot = user.username == 'root@zeynepc.arkas';
              return ListTile(
                title: Text(user.fullName),
                subtitle: Text('${user.username} • ${user.role}'),
                trailing: isRoot
                    ? const Chip(label: Text('ROOT'))
                    : IconButton(
                        icon: Icon(
                          user.isActive == 1 ? Icons.block : Icons.check_circle,
                          color: user.isActive == 1 ? Colors.red : Colors.green,
                        ),
                        onPressed: () async {
                          final auth = ref.read(authServiceProvider);
                          await auth.setUserActive(
                            user.id,
                            user.isActive != 1,
                          );
                          ref.invalidate(usersProvider);
                        },
                      ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Hata: $e')),
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final usernameCtrl = TextEditingController();
    final fullNameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    String role = 'PERSONEL';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Yeni Kullanıcı'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: fullNameCtrl,
                  decoration: const InputDecoration(labelText: 'Ad Soyad'),
                ),
                TextField(
                  controller: usernameCtrl,
                  decoration: const InputDecoration(labelText: 'Kullanıcı Adı'),
                ),
                TextField(
                  controller: passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Şifre'),
                ),
                DropdownButtonFormField<String>(
                  value: role,
                  decoration: const InputDecoration(labelText: 'Rol'),
                  items: ['MASTER', 'SECOND', 'REIS', 'PERSONEL', 'INSPECTOR']
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) => setState(() => role = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final auth = ref.read(authServiceProvider);
                final current = ref.read(currentUserProvider)!;
                final ok = await auth.createUser(
                  username: usernameCtrl.text,
                  password: passwordCtrl.text,
                  fullName: fullNameCtrl.text,
                  role: role,
                  createdById: current.id,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                ref.invalidate(usersProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok ? 'Kullanıcı eklendi' : 'Eklenemedi'),
                    ),
                  );
                }
              },
              child: const Text('Ekle'),
            ),
          ],
        ),
      ),
    );
  }
}
