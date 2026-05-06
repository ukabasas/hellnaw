import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nova3d_frontend/core/theme.dart';
import 'package:nova3d_frontend/features/auth/state/auth_provider.dart';
import 'package:nova3d_frontend/features/chat/state/chat_provider.dart';
import 'package:nova3d_frontend/shared/widgets/nova_logo.dart';

class AppSidebar extends ConsumerWidget {
  const AppSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final conversations = ref.watch(conversationsProvider);
    final currentLocation = GoRouter.of(context).state.uri.toString();

    return Container(
      width: 260,
      color: kBgSecondary,
      child: Column(
        children: [
          // Header / logo
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Row(
              children: [
                const NovaLogo(size: 28),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add, color: kTextSecondary, size: 20),
                  tooltip: 'New conversation',
                  onPressed: () => context.go('/'),
                ),
              ],
            ),
          ),
          const Divider(color: kBorderColor, height: 1),

          // New chat button
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New 3D creation'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.centerLeft,
                ),
              ),
            ),
          ),

          // Conversations label
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text('Recent',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontWeight: FontWeight.w600, fontSize: 11)),
              ],
            ),
          ),

          // Conversation list
          Expanded(
            child: conversations.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child:
                      CircularProgressIndicator(color: kAccentBlue, strokeWidth: 2),
                ),
              ),
              error: (_, _) => Center(
                child: Text('Failed to load',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
              data: (convs) => convs.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('No conversations yet',
                            style: Theme.of(context).textTheme.bodySmall),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      itemCount: convs.length,
                      itemBuilder: (_, i) {
                        final conv = convs[i];
                        final isActive =
                            currentLocation == '/chat/${conv.id}';
                        return _ConversationTile(
                          title: conv.title,
                          isActive: isActive,
                          onTap: () => context.go('/chat/${conv.id}'),
                          onDelete: () {
                            ref
                                .read(chatServiceProvider)
                                .deleteConversation(conv.id);
                            ref
                                .read(conversationsProvider.notifier)
                                .remove(conv.id);
                            if (isActive) context.go('/');
                          },
                        );
                      },
                    ),
            ),
          ),

          const Divider(color: kBorderColor, height: 1),

          // Bottom nav
          _SidebarNavItem(
            icon: Icons.workspace_premium_outlined,
            label: 'Subscription',
            isActive: currentLocation == '/subscription',
            onTap: () => context.go('/subscription'),
          ),
          _SidebarNavItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            isActive: currentLocation == '/settings',
            onTap: () => context.go('/settings'),
          ),
          const SizedBox(height: 4),

          // User row
          if (user != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: kBgTertiary,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kBorderColor),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor:
                          kAccentBlue.withValues(alpha: 0.2),
                      child: Text(
                        user.email.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                            color: kAccentBlue,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        user.email,
                        style: const TextStyle(
                            color: kTextSecondary, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout,
                          size: 16, color: kTextMuted),
                      tooltip: 'Sign out',
                      onPressed: () async {
                        await ref.read(authProvider.notifier).signOut();
                        if (context.mounted) context.go('/signin');
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ConversationTile extends StatefulWidget {
  const _ConversationTile({
    required this.title,
    required this.isActive,
    required this.onTap,
    required this.onDelete,
  });
  final String title;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  State<_ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<_ConversationTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 1),
          decoration: BoxDecoration(
            color: widget.isActive
                ? kAccentBlue.withValues(alpha: 0.12)
                : _hovering
                    ? kBgTertiary
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListTile(
            dense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            leading: Icon(
              Icons.chat_bubble_outline,
              size: 16,
              color: widget.isActive ? kAccentBlue : kTextMuted,
            ),
            title: Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: widget.isActive ? kAccentBlue : kTextSecondary,
                fontSize: 13,
              ),
            ),
            trailing: _hovering
                ? IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 15, color: kTextMuted),
                    onPressed: widget.onDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
                : null,
            onTap: widget.onTap,
          ),
        ),
      );
}

class _SidebarNavItem extends StatefulWidget {
  const _SidebarNavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<_SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<_SidebarNavItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: widget.isActive
                  ? kAccentBlue.withValues(alpha: 0.12)
                  : _hovering
                      ? kBgTertiary
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(widget.icon,
                    size: 16,
                    color:
                        widget.isActive ? kAccentBlue : kTextSecondary),
                const SizedBox(width: 10),
                Text(
                  widget.label,
                  style: TextStyle(
                    color:
                        widget.isActive ? kAccentBlue : kTextSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
