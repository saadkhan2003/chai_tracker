import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/chai_service.dart';
import '../../services/debt_service.dart';
import '../../services/group_service.dart';
import '../../services/notification_service.dart';
import '../../services/update_service.dart';
import '../../widgets/glass_card.dart';
import '../../models/chai_record_model.dart';
import '../../models/debt_model.dart';
import '../../models/user_model.dart';
import '../../models/group_model.dart';
import '../history_screen.dart';
import '../group/edit_rotation_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ChaiService _chaiService = ChaiService();
  final DebtService _debtService = DebtService();
  final GroupService _groupService = GroupService();
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Check for updates when home screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdates();
    });
  }

  Future<void> _checkForUpdates() async {
    final updateInfo = await UpdateService.checkForUpdates();
    
    if (updateInfo['hasUpdate'] && mounted) {
      _showUpdateDialog(updateInfo);
    }
  }

  void _showUpdateDialog(Map<String, dynamic> updateInfo) {
    showDialog(
      context: context,
      barrierDismissible: !updateInfo['forceUpdate'],
      builder: (context) => WillPopScope(
        onWillPop: () async => !updateInfo['forceUpdate'],
        child: AlertDialog(
          backgroundColor: AppTheme.surface,
          title: Row(
            children: [
              Icon(Icons.system_update, color: AppTheme.primaryGold),
              const SizedBox(width: 12),
              const Text('Update Available', style: TextStyle(color: AppTheme.textPrimary)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A new version is available!',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Current: ${updateInfo['currentVersion']}\nLatest: ${updateInfo['latestVersion']}',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              if (updateInfo['forceUpdate'])
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    '⚠️ This update is required to continue using the app.',
                    style: TextStyle(
                      color: AppTheme.error,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            if (!updateInfo['forceUpdate'])
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Later', style: TextStyle(color: AppTheme.textSecondary)),
              ),
            ElevatedButton(
              onPressed: () async {
                await UpdateService.downloadUpdate(updateInfo['updateUrl']);
                if (context.mounted && !updateInfo['forceUpdate']) {
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGold,
                foregroundColor: Colors.black,
              ),
              child: const Text('Update Now', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        // Show loading while groups are being fetched
        if (!provider.initialGroupsLoaded && provider.isAuthenticated) {
          return Scaffold(
            backgroundColor: AppTheme.background,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGold),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading your groups...',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          );
        }
        
        if (!provider.hasGroup) {
          return _buildNoGroupView(context, provider);
        }
        return _buildMainView(context, provider);
      },
    );
  }

  Widget _buildNoGroupView(BuildContext context, AppProvider provider) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chai Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profile',
            onPressed: () {
              Navigator.pushNamed(context, '/profile');
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await provider.logout();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryGold, AppTheme.deepGold],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Icon(
                Icons.group_add,
                size: 50,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'No Group Yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Create or join a group to start tracking chai duty',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary.withValues(alpha: 0.8),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              onPressed: () => _showCreateGroupDialog(context, provider),
              icon: const Icon(Icons.add),
              label: const Text('Create Group'),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _showJoinGroupDialog(context, provider),
              icon: const Icon(Icons.login),
              label: const Text('Join Group'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainView(BuildContext context, AppProvider provider) {
    final screens = [
      _buildHomeTab(context, provider),
      const HistoryScreen(),
      _buildDebtsTab(context, provider),
      _buildGroupTab(context, provider),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet),
            label: 'Debts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group_outlined),
            activeIcon: Icon(Icons.group),
            label: 'Group',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab(BuildContext context, AppProvider provider) {
    final group = provider.selectedGroup!;
    final todayAssignee = group.getTodayAssignee();

    return Scaffold(
      appBar: AppBar(

        title: PopupMenuButton<String>(
          offset: const Offset(0, 40),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            borderRadius: BorderRadius.circular(30),
            opacity: 0.2,
            blur: 10,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: Text(
                    group.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
          onSelected: (value) {
            if (value == 'create') {
              _showCreateGroupDialog(context, provider);
            } else if (value == 'join') {
              _showJoinGroupDialog(context, provider);
            } else {
              final selectedGroup = provider.userGroups.firstWhere((g) => g.id == value);
              provider.selectGroup(selectedGroup);
            }
          },
          itemBuilder: (context) => [
            // List of groups
            ...provider.userGroups.map((g) => PopupMenuItem(
              value: g.id,
              child: Row(
                children: [
                  if (g.id == group.id)
                    const Icon(Icons.check, size: 18, color: AppTheme.primaryGold),
                  if (g.id != group.id)
                    const SizedBox(width: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      g.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: g.id == group.id ? FontWeight.bold : FontWeight.normal,
                        color: g.id == group.id ? AppTheme.primaryGold : null,
                      ),
                    ),
                  ),
                ],
              ),
            )),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'create',
              child: Row(children: [Icon(Icons.add_circle_outline, size: 20), SizedBox(width: 8), Text('Create New Group')]),
            ),
            const PopupMenuItem(
              value: 'join',
              child: Row(children: [Icon(Icons.group_add_outlined, size: 20), SizedBox(width: 8), Text('Join Group')]),
            ),
          ],
        ),
        actions: [
          // Original swap button removed as it's now in the title
          // Keeping profile and logout buttons
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profile',
            onPressed: () {
              Navigator.pushNamed(context, '/profile');
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await provider.logout();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Ambient Background Blobs
          Positioned(
            top: -100,
            left: -50,
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
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accentAmber.withOpacity(0.1),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          
          // Main Content
          SafeArea(
            child: RefreshIndicator(
              color: AppTheme.primaryGold,
              backgroundColor: AppTheme.surface,
              onRefresh: () async {
                await provider.refreshAll();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Today's Date
                    Center(
                      child: GlassCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        opacity: 0.2,
                        borderRadius: BorderRadius.circular(30),
                        child: Text(
                          DateFormat('EEEE, MMMM d').format(DateTime.now()),
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary.withOpacity(0.9),
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Today's Chai Card
                    _buildTodayChaiCard(context, provider, todayAssignee),
                    const SizedBox(height: 32),
                    // Pending Chai Section
                    _buildPendingChaiSection(context, provider),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayChaiCard(BuildContext context, AppProvider provider, String todayAssignee) {
    return FutureBuilder<Map<String, UserModel>>(
      future: provider.getUsersById([todayAssignee]),
      builder: (context, usersSnapshot) {
        final userName = usersSnapshot.data?[todayAssignee]?.name ?? 'Loading...';
        final isMe = todayAssignee == provider.currentUser?.id;

        return StreamBuilder<ChaiRecordModel?>(
          stream: _chaiService.getTodayRecordStream(provider.selectedGroup!.id),
          builder: (context, recordSnapshot) {
            final record = recordSnapshot.data;
            final isDone = record?.isDone ?? false;

            return GlassCard(
              padding: const EdgeInsets.all(32),
              borderRadius: BorderRadius.circular(30),
              // Dynamic background tint based on status
              color: isDone 
                  ? AppTheme.success.withOpacity(0.1) 
                  : AppTheme.primaryGold.withOpacity(0.05),
              opacity: 0.2, // Backing opacity
              blur: 20,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDone 
                          ? AppTheme.success.withOpacity(0.2) 
                          : AppTheme.primaryGold.withOpacity(0.1),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (isDone ? AppTheme.success : AppTheme.primaryGold).withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      isDone ? Icons.check_circle_rounded : Icons.local_cafe_rounded,
                      size: 48,
                      color: isDone ? AppTheme.success : AppTheme.primaryGold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isDone ? 'Chai Brought! ☕' : "Today's Chai Duty",
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary.withOpacity(0.9),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isMe ? 'Your Turn!' : userName,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                      shadows: [
                        Shadow(
                          color: (isDone ? AppTheme.success : AppTheme.primaryGold).withOpacity(0.5),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (!isDone && !isMe) ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _markChaiAsDone(context, provider, todayAssignee),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.check),
                        label: const Text('Mark as Done'),
                      ),
                    ),
                  ],
                  if (!isDone && isMe) ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _markChaiAsDone(context, provider, todayAssignee),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.check),
                        label: const Text('I Brought Chai!'),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPendingChaiSection(BuildContext context, AppProvider provider) {
    return StreamBuilder<List<ChaiRecordModel>>(
      stream: _chaiService.getPendingRecords(provider.selectedGroup!.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final pendingRecords = snapshot.data!
            .where((r) => r.assignedDate.isBefore(DateTime.now().subtract(const Duration(days: 1))))
            .toList();

        if (pendingRecords.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pending Chai',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...pendingRecords.map((record) => _buildPendingRecordTile(context, provider, record)),
          ],
        );
      },
    );
  }

  Widget _buildPendingRecordTile(BuildContext context, AppProvider provider, ChaiRecordModel record) {
    return FutureBuilder<Map<String, UserModel>>(
      future: provider.getUsersById([record.assignedTo]),
      builder: (context, snapshot) {
        final userName = snapshot.data?[record.assignedTo]?.name ?? 'Loading...';

        return GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          borderRadius: BorderRadius.circular(20),
          opacity: 0.1,
          color: AppTheme.accentAmber.withOpacity(0.05),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.accentAmber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                     BoxShadow(color: AppTheme.accentAmber.withOpacity(0.2), blurRadius: 10),
                  ],
                ),
                child: const Icon(Icons.timer_outlined, color: AppTheme.accentAmber),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('MMM d').format(record.assignedDate),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary.withOpacity(0.8),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _markPendingAsDone(context, provider, record),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.success,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  backgroundColor: AppTheme.success.withOpacity(0.1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Mark Done', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryTab(BuildContext context, AppProvider provider) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
      ),
      body: StreamBuilder<List<ChaiRecordModel>>(
        stream: _chaiService.getHistory(groupId: provider.selectedGroup!.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppTheme.error.withValues(alpha: 0.7),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Index being created...\nPlease wait a moment',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: 64,
                    color: AppTheme.textSecondary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No history yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppTheme.textSecondary.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            );
          }

          final records = snapshot.data!;
          final memberIds = records.map((r) => r.assignedTo).toSet().toList();

          return FutureBuilder<Map<String, UserModel>>(
            future: provider.getUsersById(memberIds),
            builder: (context, usersSnapshot) {
              final users = usersSnapshot.data ?? {};

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: records.length,
                itemBuilder: (context, index) {
                  final record = records[index];
                  final userName = users[record.assignedTo]?.name ?? 'Unknown';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: record.isDone
                                ? AppTheme.success.withValues(alpha: 0.2)
                                : AppTheme.accentAmber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            record.isDone ? Icons.check_circle : Icons.pending,
                            color: record.isDone ? AppTheme.success : AppTheme.accentAmber,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Assigned: ${DateFormat('MMM d, yyyy').format(record.assignedDate)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary.withValues(alpha: 0.8),
                                ),
                              ),
                              if (record.markedAt != null)
                                Text(
                                  'Completed: ${DateFormat('MMM d, yyyy').format(record.markedAt!)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.success.withValues(alpha: 0.8),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: record.isDone
                                ? AppTheme.success.withValues(alpha: 0.2)
                                : AppTheme.accentAmber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            record.isDone ? 'Done' : 'Pending',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: record.isDone ? AppTheme.success : AppTheme.accentAmber,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDebtsTab(BuildContext context, AppProvider provider) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Debts'),
          bottom: const TabBar(
            indicatorColor: AppTheme.primaryGold,
            labelColor: AppTheme.primaryGold,
            unselectedLabelColor: AppTheme.textSecondary,
            isScrollable: true,
            tabs: [
              Tab(text: 'Requests'),
              Tab(text: 'Owed to Me'),
              Tab(text: 'I Owe'),
              Tab(text: 'History'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showCreateDebtDialog(context, provider),
          child: const Icon(Icons.add),
        ),
        body: TabBarView(
          children: [
            _buildDebtRequestsTab(context, provider),
            _buildDebtsOwedToMeTab(context, provider),
            _buildDebtsIIOweTab(context, provider),
            _buildDebtHistoryTab(context, provider),
          ],
        ),
      ),
    );
  }

  Widget _buildDebtRequestsTab(BuildContext context, AppProvider provider) {
    return StreamBuilder<List<DebtModel>>(
      stream: _debtService.getPendingDebtRequests(provider.currentUser!.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(
            icon: Icons.inbox_outlined,
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
                  cardType: 'request',
                  onAccept: () => _acceptDebt(context, debt.id),
                  onReject: () => _rejectDebt(context, debt.id),
                  onEdit: () => _showEditDebtDialog(context, debt),
                  onDelete: () => _showDeleteDebtDialog(context, debt.id),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildDebtsOwedToMeTab(BuildContext context, AppProvider provider) {
    return StreamBuilder<List<DebtModel>>(
      stream: _debtService.getDebtsOwedToUser(provider.currentUser!.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildEmptyState(
            icon: Icons.hourglass_empty,
            title: 'Index Building...',
            subtitle: 'Please wait a moment',
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final debts = snapshot.data!.where((d) => d.isAccepted).toList();
        if (debts.isEmpty) {
          return _buildEmptyState(
            icon: Icons.trending_up,
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
                  cardType: 'owedToMe',
                  onSettle: () => _settleDebt(context, debt.id),
                  onEdit: () => _showEditDebtDialog(context, debt),
                  onDelete: () => _showDeleteDebtDialog(context, debt.id),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildDebtsIIOweTab(BuildContext context, AppProvider provider) {
    return StreamBuilder<List<DebtModel>>(
      stream: _debtService.getDebtsOwedByUser(provider.currentUser!.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildEmptyState(
            icon: Icons.hourglass_empty,
            title: 'Index Building...',
            subtitle: 'Please wait a moment',
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final debts = snapshot.data!.where((d) => d.isAccepted).toList();
        if (debts.isEmpty) {
          return _buildEmptyState(
            icon: Icons.trending_down,
            title: 'You\'re All Clear!',
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
                  cardType: 'iOwe',
                  onDelete: () => _showDeleteDebtDialog(context, debt.id),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildDebtHistoryTab(BuildContext context, AppProvider provider) {
    return StreamBuilder<List<DebtModel>>(
      stream: _debtService.getDebtHistory(provider.currentUser!.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildEmptyState(
            icon: Icons.hourglass_empty,
            title: 'Loading...',
            subtitle: 'Please wait',
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final debts = snapshot.data!;
        if (debts.isEmpty) {
          return _buildEmptyState(
            icon: Icons.receipt_long,
            title: 'No Debt History',
            subtitle: 'Settled and rejected debts will appear here',
          );
        }

        final userIds = debts.expand((d) => [d.fromUserId, d.toUserId]).toSet().toList();

        return FutureBuilder<Map<String, UserModel>>(
          future: provider.getUsersById(userIds),
          builder: (context, usersSnapshot) {
            final users = usersSnapshot.data ?? {};

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: debts.length,
              itemBuilder: (context, index) {
                final debt = debts[index];
                final isMyDebt = debt.fromUserId == provider.currentUser!.id;
                final otherUserId = isMyDebt ? debt.toUserId : debt.fromUserId;
                final otherUser = users[otherUserId];

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      // Status icon
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: debt.isSettled
                              ? AppTheme.success.withValues(alpha: 0.2)
                              : AppTheme.error.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          debt.isSettled ? Icons.check_circle : Icons.cancel,
                          color: debt.isSettled ? AppTheme.success : AppTheme.error,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isMyDebt 
                                  ? '${otherUser?.name ?? 'Unknown'} owed you'
                                  : 'You owed ${otherUser?.name ?? 'Unknown'}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            Text(
                              'Rs. ${debt.amount.toStringAsFixed(0)} - ${debt.reason}',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: debt.isSettled
                              ? AppTheme.success.withValues(alpha: 0.2)
                              : AppTheme.error.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          debt.isSettled ? 'Settled' : 'Rejected',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: debt.isSettled ? AppTheme.success : AppTheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
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
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Icon(icon, size: 48, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.8)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebtCard({
    required BuildContext context,
    required DebtModel debt,
    required String userName,
    required String cardType,
    VoidCallback? onAccept,
    VoidCallback? onReject,
    VoidCallback? onSettle,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
  }) {
    final isRequest = cardType == 'request';
    final isOwedToMe = cardType == 'owedToMe';
    final isIOwe = cardType == 'iOwe';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRequest
              ? AppTheme.accentAmber.withValues(alpha: 0.5)
              : isOwedToMe
                  ? AppTheme.success.withValues(alpha: 0.5)
                  : AppTheme.error.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isRequest
                        ? [AppTheme.accentAmber.withValues(alpha: 0.3), AppTheme.accentAmber.withValues(alpha: 0.1)]
                        : isOwedToMe
                            ? [AppTheme.success.withValues(alpha: 0.3), AppTheme.success.withValues(alpha: 0.1)]
                            : [AppTheme.error.withValues(alpha: 0.3), AppTheme.error.withValues(alpha: 0.1)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isRequest
                      ? Icons.pending_actions
                      : isOwedToMe
                          ? Icons.arrow_downward_rounded
                          : Icons.arrow_upward_rounded,
                  color: isRequest
                      ? AppTheme.accentAmber
                      : isOwedToMe
                          ? AppTheme.success
                          : AppTheme.error,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isRequest
                          ? 'Sent you a request'
                          : isOwedToMe
                              ? 'Owes you'
                              : 'You owe',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Rs. ${debt.amount.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isOwedToMe ? AppTheme.success : (isIOwe ? AppTheme.error : AppTheme.primaryGold),
                    ),
                  ),
                  Text(
                    DateFormat('MMM d').format(debt.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              if (onEdit != null || onDelete != null)
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: AppTheme.textSecondary.withValues(alpha: 0.7)),
                  onSelected: (value) {
                    if (value == 'edit' && onEdit != null) onEdit();
                    if (value == 'delete' && onDelete != null) onDelete();
                  },
                  itemBuilder: (context) => [
                    if (onEdit != null)
                      const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Edit')])),
                    if (onDelete != null)
                      const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: AppTheme.error), SizedBox(width: 8), Text('Delete', style: TextStyle(color: AppTheme.error))])),
                  ],
                ),
            ],
          ),
          if (debt.reason.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.note_outlined, size: 18, color: AppTheme.textSecondary.withValues(alpha: 0.7)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      debt.reason,
                      style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.9), fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (isRequest) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.error,
                      side: const BorderSide(color: AppTheme.error),
                      padding: const EdgeInsets.symmetric(vertical: 12),
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
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
          if (isOwedToMe) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onSettle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.check_circle_outline, size: 20),
                label: const Text('Mark as Settled'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _acceptDebt(BuildContext context, String debtId) async {
    try {
      await _debtService.acceptDebt(debtId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debt accepted ✓'), backgroundColor: AppTheme.success),
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
          const SnackBar(content: Text('Debt settled! 🎉'), backgroundColor: AppTheme.success),
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

  void _showEditDebtDialog(BuildContext context, DebtModel debt) {
    final amountController = TextEditingController(text: debt.amount.toStringAsFixed(0));
    final reasonController = TextEditingController(text: debt.reason);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Debt'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount (Rs.)',
                prefixIcon: Icon(Icons.currency_rupee),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason',
                prefixIcon: Icon(Icons.note_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text) ?? 0;
              if (amount > 0) {
                Navigator.pop(dialogContext);
                try {
                  await _debtService.updateDebt(
                    debtId: debt.id,
                    amount: amount,
                    reason: reasonController.text.trim(),
                  );
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(content: Text('Debt updated ✓'), backgroundColor: AppTheme.success),
                  );
                } catch (e) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDebtDialog(BuildContext context, String debtId) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Debt?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await _debtService.deleteDebt(debtId);
                scaffoldMessenger.showSnackBar(
                  const SnackBar(content: Text('Debt deleted')),
                );
              } catch (e) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showCreateDebtDialog(BuildContext context, AppProvider provider) {
    final amountController = TextEditingController();
    final reasonController = TextEditingController();
    String? selectedUserId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.textSecondary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Create Debt Request',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Request money from a friend',
                    style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.8)),
                  ),
                  const SizedBox(height: 24),
                  const Text('Who owes you?', style: TextStyle(fontWeight: FontWeight.w600)),
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
                        return const LinearProgressIndicator();
                      }

                      final users = snapshot.data!;
                      return DropdownButtonFormField<String>(
                        decoration: const InputDecoration(hintText: 'Select friend'),
                        value: selectedUserId,
                        items: users.entries
                            .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value.name)))
                            .toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedUserId = value;
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixText: 'Rs. ',
                      prefixIcon: Icon(Icons.currency_rupee, color: AppTheme.primaryGold),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: reasonController,
                    decoration: const InputDecoration(
                      labelText: 'Reason (optional)',
                      hintText: 'e.g., Chai money',
                      prefixIcon: Icon(Icons.note_outlined, color: AppTheme.primaryGold),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 28),
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
                                  content: Text('Debt request sent! 📤'),
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
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Send Request', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        },
      ),
    );
  }


  Widget _buildGroupTab(BuildContext context, AppProvider provider) {
    final group = provider.selectedGroup!;
    final isAdmin = group.adminId == provider.currentUser!.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Group'),
        actions: [
          IconButton(
             icon: const Icon(Icons.settings_outlined),
             onPressed: () => _showGroupSettingsBottomSheet(context, provider, group),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await provider.logout();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Group Info Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryGold.withValues(alpha: 0.2), AppTheme.deepGold.withValues(alpha: 0.1)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.group, size: 48, color: AppTheme.primaryGold),
                  const SizedBox(height: 12),
                  Text(
                    group.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Code: ',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                        Text(
                          group.code,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: group.code));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Invite code copied! ✓'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          child: const Icon(Icons.copy, size: 18, color: AppTheme.primaryGold),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            Share.share(
                              'Join my Chai Tracker group!\n\nGroup: ${group.name}\nCode: ${group.code}\n\nDownload the app and use this code to join!',
                              subject: 'Join ${group.name} on Chai Tracker',
                            );
                          },
                          child: const Icon(Icons.share, size: 18, color: AppTheme.primaryGold),
                        ),
// Email invite button removed
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Members Section
            const Text(
              'Members',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<Map<String, UserModel>>(
              future: provider.getUsersById(group.memberOrder),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final users = snapshot.data!;
                final todayAssignee = group.getTodayAssignee();
                // Calculate tomorrow's assignee
                final todayIndex = group.memberOrder.indexOf(todayAssignee);
                final tomorrowIndex = (todayIndex + 1) % group.memberOrder.length;
                final tomorrowAssignee = group.memberOrder[tomorrowIndex];
                
                return Column(
                  children: group.memberOrder.asMap().entries.map((entry) {
                    final index = entry.key;
                    final userId = entry.value;
                    final user = users[userId];
                    final isAdmin = userId == group.adminId;
                    final isMe = userId == provider.currentUser?.id;
                    final isToday = userId == todayAssignee;
                    final isTomorrow = userId == tomorrowAssignee;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isToday 
                            ? AppTheme.success.withValues(alpha: 0.1)
                            : AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: isToday
                            ? Border.all(color: AppTheme.success.withValues(alpha: 0.5), width: 1.5)
                            : isMe
                                ? Border.all(color: AppTheme.primaryGold.withOpacity(0.5))
                                : null,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Number badge
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isToday 
                                  ? AppTheme.success.withOpacity(0.3) 
                                  : AppTheme.primaryGold.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isToday ? AppTheme.success : AppTheme.primaryGold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Name and badges
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Name row
                                Text(
                                  '${user?.name ?? 'Unknown'}${isMe ? ' (You)' : ''}',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                // Badges row
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    if (isToday)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.success,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          '☕ Today',
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                      ),
                                    if (isTomorrow)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.accentAmber,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'Tomorrow',
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                      ),
                                    if (isAdmin)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryGold,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'Admin',
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black),
                                        ),
                                      ),
                                    if (user?.phone != null && user!.phone.isNotEmpty)
                                      Text(
                                        user.phone,
                                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary.withValues(alpha: 0.7)),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 24),
            // Actions
            if (provider.userGroups.length > 1)
              OutlinedButton.icon(
                onPressed: () => _showCreateGroupDialog(context, provider),
                icon: const Icon(Icons.add),
                label: const Text('Create Another Group'),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _showJoinGroupDialog(context, provider),
              icon: const Icon(Icons.login),
              label: const Text('Join Another Group'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markChaiAsDone(BuildContext context, AppProvider provider, String assignedTo) async {
    try {
      final record = await _chaiService.getOrCreateTodayRecord(
        groupId: provider.selectedGroup!.id,
        assignedTo: assignedTo,
      );
      await _chaiService.markAsDone(
        recordId: record.id,
        broughtBy: provider.currentUser!.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chai marked as done! ☕'),
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

  Future<void> _markPendingAsDone(BuildContext context, AppProvider provider, ChaiRecordModel record) async {
    try {
      await _chaiService.markAsDone(
        recordId: record.id,
        broughtBy: record.assignedTo,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Marked as done! ☕'),
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

  void _showCreateGroupDialog(BuildContext context, AppProvider provider) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Group'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Group Name',
            hintText: 'e.g., Chai Squad',
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                Navigator.pop(context);
                await provider.createGroup(controller.text.trim());
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showJoinGroupDialog(BuildContext context, AppProvider provider) {
    final controller = TextEditingController();
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassCard(
          opacity: 0.1,
          blur: 15,
          borderRadius: BorderRadius.circular(24),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              const Text(
                'Join Group',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the 6-character code shared by your friend',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: controller,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                  color: AppTheme.primaryGold,
                ),
                decoration: InputDecoration(
                  hintText: 'A1B2C3',
                  hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                  filled: true,
                  fillColor: AppTheme.surface.withValues(alpha: 0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
                textCapitalization: TextCapitalization.characters,
                maxLength: 6,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (controller.text.length == 6) {
                          Navigator.pop(dialogContext);
                          final success = await provider.joinGroup(controller.text.trim().toUpperCase());
                          if (success) {
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(
                                content: Text('Joined group successfully! ✓'),
                                backgroundColor: AppTheme.success,
                              ),
                            );
                          } else if (provider.error != null) {
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text(provider.error!),
                                backgroundColor: AppTheme.error,
                              ),
                            );
                            provider.clearError();
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppTheme.primaryGold,
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('Join', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showGroupSettingsBottomSheet(BuildContext context, AppProvider provider, GroupModel group) {
    final isAdmin = group.adminId == provider.currentUser!.id;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surface.withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Group Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            if (isAdmin) ...[
              _buildSettingsOption(
                icon: Icons.edit_outlined,
                title: 'Edit Group Name',
                onTap: () {
                  Navigator.pop(context);
                  _showEditGroupDialog(context, provider, group);
                },
              ),
              const SizedBox(height: 16),
              _buildSettingsOption(
                icon: Icons.notifications_outlined,
                title: 'Daily Reminder',
                subtitle: group.hasReminder ? group.reminderTimeFormatted : 'Not set',
                onTap: () {
                  Navigator.pop(context);
                  _showSetReminderDialog(context, provider, group);
                },
              ),
              const SizedBox(height: 16),
              _buildSettingsOption(
                icon: Icons.swap_vert,
                title: 'Edit Rotation Order',
                subtitle: 'Customize chai duty sequence',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditRotationScreen(group: group),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Divider(color: Colors.white.withValues(alpha: 0.1)),
              const SizedBox(height: 16),
              _buildSettingsOption(
                icon: Icons.delete_outline,
                title: 'Delete Group',
                color: AppTheme.error,
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteGroupDialog(context, provider, group);
                },
              ),
            ] else 
              _buildSettingsOption(
                icon: Icons.exit_to_app,
                title: 'Leave Group',
                color: AppTheme.error,
                onTap: () {
                  Navigator.pop(context);
                  _showLeaveGroupDialog(context, provider, group);
                },
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsOption({
    required IconData icon,
    required String title,
    String? subtitle,
    Color color = AppTheme.textPrimary,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary.withValues(alpha: 0.7),
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.2)),
          ],
        ),
      ),
    );
  }

  void _showEditGroupDialog(BuildContext context, AppProvider provider, GroupModel group) {
    final controller = TextEditingController(text: group.name);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassCard(
          opacity: 0.1,
          blur: 15,
          borderRadius: BorderRadius.circular(24),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Edit Group Name',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Group Name',
                  filled: true,
                  fillColor: AppTheme.surface.withValues(alpha: 0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (controller.text.trim().isNotEmpty) {
                          Navigator.pop(dialogContext);
                          try {
                            await _groupService.updateGroup(
                              groupId: group.id,
                              name: controller.text.trim(),
                            );
                            await provider.refreshGroups();
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(content: Text('Group updated ✓'), backgroundColor: AppTheme.success),
                            );
                          } catch (e) {
                            scaffoldMessenger.showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppTheme.primaryGold,
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLeaveGroupDialog(BuildContext context, AppProvider provider, GroupModel group) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final isAdmin = group.adminId == provider.currentUser!.id;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassCard(
          opacity: 0.1,
          blur: 15,
          borderRadius: BorderRadius.circular(24),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppTheme.error, size: 40),
              const SizedBox(height: 16),
              const Text(
                'Leave Group?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                isAdmin && group.members.length > 1
                    ? 'You are admin. You will lose admin rights.'
                    : 'You will no longer see this group\'s data.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.8)),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(dialogContext);
                        try {
                          await _groupService.leaveGroup(group.id, provider.currentUser!.id);
                          await provider.refreshGroups();
                          scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Left group')));
                        } catch (e) {
                          scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppTheme.error,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Leave', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteGroupDialog(BuildContext context, AppProvider provider, GroupModel group) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassCard(
          opacity: 0.1,
          blur: 15,
          borderRadius: BorderRadius.circular(24),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.delete_forever, color: AppTheme.error, size: 40),
              const SizedBox(height: 16),
              const Text(
                'Delete Group?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'Permanently delete "${group.name}" and all data. Undonable.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.8)),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(dialogContext);
                        try {
                          await _groupService.deleteGroup(group.id);
                          await provider.refreshGroups();
                          scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Group deleted')));
                        } catch (e) {
                          scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppTheme.error,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSetReminderDialog(BuildContext context, AppProvider provider, GroupModel group) {
    TimeOfDay selectedTime = TimeOfDay(
      hour: group.reminderHour ?? 9,
      minute: group.reminderMinute ?? 0,
    );
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassCard(
          opacity: 0.1,
          blur: 15,
          borderRadius: BorderRadius.circular(24),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.notifications_active, color: AppTheme.primaryGold, size: 40),
              const SizedBox(height: 16),
              const Text(
                'Daily Reminder',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              StatefulBuilder(
                builder: (context, setState) {
                  return Column(
                    children: [
                      const Text('Notify everyone at:', style: TextStyle(color: AppTheme.textSecondary)),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () async {
                          final TimeOfDay? picked = await showTimePicker(
                            context: context,
                            initialTime: selectedTime,
                            builder: (context, child) {
                              return Theme(
                                data: ThemeData.dark().copyWith(
                                  colorScheme: const ColorScheme.dark(
                                    primary: AppTheme.primaryGold,
                                    onPrimary: Colors.black,
                                    surface: Color(0xFF1E1E1E),
                                    onSurface: Colors.white,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null && picked != selectedTime) {
                            setState(() {
                              selectedTime = picked;
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppTheme.primaryGold),
                            borderRadius: BorderRadius.circular(12),
                            color: AppTheme.primaryGold.withValues(alpha: 0.1),
                          ),
                          child: Text(
                            selectedTime.format(context),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryGold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  if (group.hasReminder) ...[
                     Expanded(
                      child: TextButton(
                        onPressed: () async {
                          Navigator.pop(dialogContext);
                          try {
                            await _groupService.clearReminderTime(group.id);
                            await NotificationService().cancelChaiReminder(group.id);
                            await provider.refreshGroups();
                            scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Reminder disabled')));
                          } catch (e) {
                            scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
                          }
                        },
                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                        child: const Text('Turn Off', style: TextStyle(color: AppTheme.error)),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(dialogContext);
                        try {
                          await _groupService.setReminderTime(
                            groupId: group.id,
                            hour: selectedTime.hour,
                            minute: selectedTime.minute,
                          );
                          await NotificationService().scheduleChaiRemindersForNextTwoWeeks(
                            hour: selectedTime.hour,
                            minute: selectedTime.minute,
                            groupId: group.id,
                            groupName: group.name,
                            memberOrder: group.memberOrder,
                            groupCreatedAt: group.createdAt,
                            getMemberName: (id) async => await provider.getUserName(id),
                          );
                          await provider.refreshGroups();
                          scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Reminder set successfully ✓'), backgroundColor: AppTheme.success));
                        } catch (e) {
                          scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppTheme.primaryGold,
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('Save Reminder', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
