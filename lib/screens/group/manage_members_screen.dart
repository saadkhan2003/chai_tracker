import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../models/group_model.dart';
import '../../services/group_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class ManageMembersScreen extends StatelessWidget {
  final GroupModel group;

  const ManageMembersScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final groupService = GroupService();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Manage Members'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info card
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppTheme.primaryGold),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tap the menu icon (:) to remove a member',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Members list
            Expanded(
              child: ListView.builder(
                itemCount: group.members.length,
                itemBuilder: (context, index) {
                  final memberId = group.members[index];
                  final isAdmin = memberId == group.adminId;

                  return FutureBuilder<String>(
                    future: provider.getUserName(memberId),
                    builder: (context, snapshot) {
                      final name = snapshot.data ?? 'Loading...';
                      final isCurrentUser = memberId == provider.currentUser?.id;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GlassCard(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              // Avatar circle
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryGold.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                                    style: TextStyle(
                                      color: AppTheme.primaryGold,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Member info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          name,
                                          style: TextStyle(
                                            color: AppTheme.textPrimary,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 16,
                                          ),
                                        ),
                                        if (isAdmin) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primaryGold.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'Admin',
                                              style: TextStyle(
                                                color: AppTheme.primaryGold,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (isCurrentUser)
                                      Text(
                                        '(You)',
                                        style: TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                              // Remove button (menu icon)
                              if (!isAdmin)
                                IconButton(
                                  icon: Icon(
                                    Icons.more_vert,
                                    color: AppTheme.error,
                                  ),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (dialogContext) => AlertDialog(
                                        backgroundColor: AppTheme.surface,
                                        title: Row(
                                          children: [
                                            Icon(Icons.person_remove, color: AppTheme.error),
                                            const SizedBox(width: 12),
                                            const Text('Remove Member?', style: TextStyle(color: AppTheme.textPrimary)),
                                          ],
                                        ),
                                        content: Text(
                                          'Are you sure you want to remove $name from the group? They will lose access immediately.',
                                          style: TextStyle(color: AppTheme.textSecondary),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(dialogContext),
                                            child: const Text('Cancel'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () async {
                                              Navigator.pop(dialogContext);
                                              try {
                                                await groupService.removeMember(group.id, memberId);
                                                
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text('$name removed from group'),
                                                      backgroundColor: AppTheme.success,
                                                    ),
                                                  );
                                                }
                                              } catch (e) {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text('Error: $e'),
                                                      backgroundColor: AppTheme.error,
                                                    ),
                                                  );
                                                }
                                              }
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppTheme.error,
                                              foregroundColor: Colors.white,
                                            ),
                                            child: const Text('Remove'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
