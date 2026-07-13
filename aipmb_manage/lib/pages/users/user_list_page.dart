import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aipmb_manage/providers/user_provider.dart';

class UserListPage extends ConsumerStatefulWidget {
  const UserListPage({super.key});

  @override
  ConsumerState<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends ConsumerState<UserListPage> {
  final _searchCtrl = TextEditingController();
  String _keyword = '';

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersProvider(_keyword));

    return Scaffold(
      appBar: AppBar(title: const Text('用户管理')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: '搜索用户姓名...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _keyword = v),
            ),
          ),
          Expanded(
            child: usersAsync.when(
              data: (users) => users.isEmpty
                  ? const Center(child: Text('暂无用户'))
                  : ListView.builder(
                      itemCount: users.length,
                      itemBuilder: (_, i) {
                        final u = users[i];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: ListTile(
                            title: Text(u.name),
                            subtitle: Text(
                              '${u.accountCount}个账户 · 余额 ¥${u.totalBalance.toStringAsFixed(0)} · 信用 ¥${u.totalCreditLimit.toStringAsFixed(0)}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.push('/users/${u.name}'),
                          ),
                        );
                      },
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('加载失败: $e')),
            ),
          ),
        ],
      ),
    );
  }
}