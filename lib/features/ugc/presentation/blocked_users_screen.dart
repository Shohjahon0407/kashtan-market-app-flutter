import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/failure_l10n.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/routing/back_navigation.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../data/ugc_api.dart';

class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(blockedUsersProvider);
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(l10n.ugcBlockedUsers),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                error is ApiFailure ? error.localize(l10n) : l10n.errorUnknown,
                textAlign: TextAlign.center,
              ),
              TextButton(
                onPressed: () => ref.invalidate(blockedUsersProvider),
                child: Text(l10n.commonRetry),
              ),
            ],
          ),
        ),
        data: (users) {
          if (users.isEmpty) {
            return Center(child: Text(l10n.ugcBlockedUsersEmpty));
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(blockedUsersProvider.future),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: users.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final user = users[index];
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      user.displayName.isEmpty
                          ? '?'
                          : user.displayName[0].toUpperCase(),
                    ),
                  ),
                  title: Text(user.displayName),
                  trailing: TextButton(
                    onPressed: () async {
                      try {
                        await ref.read(ugcApiProvider).unblockUser(user.id);
                        ref.invalidate(blockedUsersProvider);
                      } on Object catch (error) {
                        if (!context.mounted) return;
                        final message = error is ApiFailure
                            ? error.localize(l10n)
                            : l10n.errorUnknown;
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(message)));
                      }
                    },
                    child: Text(l10n.ugcUnblock),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
