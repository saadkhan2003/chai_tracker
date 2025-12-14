import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/debt_service.dart';
import '../../models/debt_model.dart';
import '../../models/user_model.dart';
import 'package:intl/intl.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/glass_segmented_control.dart';

class DebtsScreen extends StatefulWidget {
  const DebtsScreen({super.key});

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> with SingleTickerProviderStateMixin {
  final DebtService _debtService = DebtService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: const Text('Debts'),
            backgroundColor: Colors.transparent,
            centerTitle: true,
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: AppTheme.primaryGold,
            foregroundColor: Colors.black,
            onPressed: () => _showCreateDebtDialog(context, provider),
            child: const Icon(Icons.add),
          ),
          body: Stack(
            children: [
              // Background Gradient Blobs
              Positioned(
                top: -100,
                right: -100,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primaryGold.withOpacity(0.15),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ),
              Positioned(
                bottom: -50,
                left: -50,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.deepGold.withOpacity(0.1),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ),
              
              Column(
                children: [
                   // Spacing for AppBar
                  SizedBox(height: MediaQuery.of(context).padding.top + 60),
                  
                  // Custom Glass Segmented Control
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: GlassSegmentedControl(
                      selectedIndex: _tabController.index,
                      tabs: const ['Requests', 'Owed to Me', 'I Owe'],
                      onTabSelected: (index) {
                        setState(() {
                          _tabController.animateTo(index);
                        });
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Tab View
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _buildRequestsTab(context, provider),
                        _buildOwedToMeTab(context, provider),
                        _buildIOweTab(context, provider),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRequestsTab(BuildContext context, AppProvider provider) {
    return StreamBuilder<List<DebtModel>>(
      stream: _debtService.getPendingDebtRequests(provider.currentUser?.id ?? ''),
      builder: (context, snapshot) {
        if (!context.mounted) return const SizedBox.shrink(); // Safety check
        if (provider.currentUser == null) return const Center(child: CircularProgressIndicator());

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(
            icon: Icons.inbox,
            title: 'No Pending Requests',
            subtitle: 'Debt requests from friends will appear here',
          );
        }

        final requests = snapshot.data!;
        final userIds = requests.map((d) => d.fromUserId).toSet().toList();

        return FutureBuilder<Map<String, UserModel>>(
          future: provider.getUsersById(userIds),
          builder: (context, usersSnapshot) {
            final users = usersSnapshot.data ?? {};

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final debt = requests[index];
                final fromUser = users[debt.fromUserId];

                return _buildDebtCard(
                  context: context,
                  debt: debt,
                  userName: fromUser?.name ?? 'Unknown',
                  isRequest: true,
                  onAccept: () => _acceptDebt(context, debt.id),
                  onReject: () => _rejectDebt(context, debt.id),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildOwedToMeTab(BuildContext context, AppProvider provider) {
    return StreamBuilder<List<DebtModel>>(
      stream: _debtService.getDebtsOwedToUser(provider.currentUser?.id ?? ''),
      builder: (context, snapshot) {
        if (provider.currentUser == null) return const SizedBox.shrink();

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(
            icon: Icons.account_balance,
            title: 'No Active Debts',
            subtitle: 'Money owed to you will appear here',
          );
        }

        final debts = snapshot.data!.where((d) => d.isAccepted).toList();
        if (debts.isEmpty) {
          return _buildEmptyState(
            icon: Icons.account_balance,
            title: 'No Active Debts',
            subtitle: 'Money owed to you will appear here',
          );
        }

        final userIds = debts.map((d) => d.toUserId).toSet().toList();

        return FutureBuilder<Map<String, UserModel>>(
          future: provider.getUsersById(userIds),
          builder: (context, usersSnapshot) {
            final users = usersSnapshot.data ?? {};

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: debts.length,
              itemBuilder: (context, index) {
                final debt = debts[index];
                final toUser = users[debt.toUserId];

                return _buildDebtCard(
                  context: context,
                  debt: debt,
                  userName: toUser?.name ?? 'Unknown',
                  isOwedToMe: true,
                  onSettle: () => _settleDebt(context, debt.id),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildIOweTab(BuildContext context, AppProvider provider) {
    return StreamBuilder<List<DebtModel>>(
      stream: _debtService.getDebtsOwedByUser(provider.currentUser?.id ?? ''),
      builder: (context, snapshot) {
        if (provider.currentUser == null) return const SizedBox.shrink();

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(
            icon: Icons.money_off,
            title: 'No Debts',
            subtitle: 'Money you owe will appear here',
          );
        }

        final debts = snapshot.data!.where((d) => d.isAccepted).toList();
        if (debts.isEmpty) {
          return _buildEmptyState(
            icon: Icons.money_off,
            title: 'No Debts',
            subtitle: 'Money you owe will appear here',
          );
        }

        final userIds = debts.map((d) => d.fromUserId).toSet().toList();

        return FutureBuilder<Map<String, UserModel>>(
          future: provider.getUsersById(userIds),
          builder: (context, usersSnapshot) {
            final users = usersSnapshot.data ?? {};

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: debts.length,
              itemBuilder: (context, index) {
                final debt = debts[index];
                final fromUser = users[debt.fromUserId];

                return _buildDebtCard(
                  context: context,
                  debt: debt,
                  userName: fromUser?.name ?? 'Unknown',
                  isIOwe: true,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppTheme.textSecondary.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: AppTheme.textSecondary.withOpacity(0.8)),
          ),
        ],
      ),
    );
  }

  Widget _buildDebtCard({
    required BuildContext context,
    required DebtModel debt,
    required String userName,
    bool isRequest = false,
    bool isOwedToMe = false,
    bool isIOwe = false,
    VoidCallback? onAccept,
    VoidCallback? onReject,
    VoidCallback? onSettle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.all(16),
        opacity: 0.05,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isRequest
                        ? AppTheme.accentAmber.withOpacity(0.2)
                        : isOwedToMe
                            ? AppTheme.success.withOpacity(0.2)
                            : AppTheme.error.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isRequest
                        ? Icons.pending_actions
                        : isOwedToMe
                            ? Icons.arrow_downward
                            : Icons.arrow_upward,
                    color: isRequest
                        ? AppTheme.accentAmber
                        : isOwedToMe
                            ? AppTheme.success
                            : AppTheme.error,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.white),
                      ),
                      Text(
                        isRequest
                            ? 'Sent you a request'
                            : isOwedToMe
                                ? 'Owes you'
                                : 'You owe',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Rs. ${debt.amount.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isOwedToMe ? AppTheme.success : AppTheme.error,
                  ),
                ),
              ],
            ),
            if (debt.reason.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.note, size: 16, color: AppTheme.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        debt.reason,
                        style: TextStyle(color: AppTheme.textSecondary.withOpacity(0.9)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              DateFormat('MMM d, yyyy').format(debt.createdAt),
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary.withOpacity(0.6),
              ),
            ),
            if (isRequest) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onReject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.error,
                        side: const BorderSide(color: AppTheme.error),
                      ),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onAccept,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Accept'),
                    ),
                  ),
                ],
              ),
            ],
            if (isOwedToMe) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onSettle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Mark as Settled'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _acceptDebt(BuildContext context, String debtId) async {
    try {
      await _debtService.acceptDebt(debtId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debt accepted'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _rejectDebt(BuildContext context, String debtId) async {
    try {
      await _debtService.rejectDebt(debtId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debt rejected')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _settleDebt(BuildContext context, String debtId) async {
    try {
      await _debtService.settleDebt(debtId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debt settled! 🎉'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  void _showCreateDebtDialog(BuildContext context, AppProvider provider) {
    if (provider.selectedGroup == null) return;
    
    final amountController = TextEditingController();
    final reasonController = TextEditingController();
    String? selectedUserId;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppTheme.surface,
            title: const Text('Create Debt Request'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Who owes you?',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<Map<String, UserModel>>(
                    future: provider.getUsersById(
                      provider.selectedGroup?.members
                              .where((id) => id != provider.currentUser?.id)
                              .toList() ??
                          [],
                    ),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator()));
                      }

                      final users = snapshot.data!;
                      return DropdownButtonFormField<String>(
                        dropdownColor: AppTheme.surface,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Select friend',
                        ),
                        value: selectedUserId,
                        items: users.entries
                            .map((e) => DropdownMenuItem(
                                  value: e.key,
                                  child: Text(e.value.name),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedUserId = value;
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Amount (Rs.)',
                      prefixText: 'Rs. ',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: reasonController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Reason (optional)',
                      hintText: 'e.g., Chai money',
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (selectedUserId != null && amountController.text.isNotEmpty) {
                    final amount = double.tryParse(amountController.text);
                    if (amount != null && amount > 0) {
                      Navigator.pop(dialogContext);
                      try {
                        await _debtService.createDebt(
                          fromUserId: provider.currentUser!.id,
                          toUserId: selectedUserId!,
                          groupId: provider.selectedGroup!.id,
                          amount: amount,
                          reason: reasonController.text.trim(),
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Debt request sent!'),
                              backgroundColor: AppTheme.success,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: AppTheme.error,
                            ),
                          );
                        }
                      }
                    }
                  }
                },
                child: const Text('Send Request'),
              ),
            ],
          );
        },
      ),
    );
  }
}
