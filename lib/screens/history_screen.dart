import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../services/chai_service.dart';
import '../models/chai_record_model.dart';
import '../models/user_model.dart';
import '../widgets/glass_card.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ChaiService _chaiService = ChaiService();
  final TextEditingController _searchController = TextEditingController();
  
  DateTime _selectedMonth = DateTime.now();
  String _searchQuery = '';
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _pickMonth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppTheme.primaryGold,
              onPrimary: Colors.black,
              surface: AppTheme.surface,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedMonth) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month);
      });
    }
  }

  void _showDeleteRecordDialog(BuildContext context, String recordId) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Delete Record?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await _chaiService.deleteRecord(recordId);
                scaffoldMessenger.showSnackBar(
                  const SnackBar(content: Text('Record deleted')),
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

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        if (provider.selectedGroup == null) {
          return const Center(child: Text('No group selected'));
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('History'),
            actions: [
              IconButton(
                icon: const Icon(Icons.calendar_month),
                tooltip: 'Filter by Month',
                onPressed: _pickMonth,
              ),
            ],
          ),
          body: Column(
            children: [
              // Month selector and search
              GlassCard(
                borderRadius: BorderRadius.zero,
                opacity: 0.05,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Month display
                      GestureDetector(
                        onTap: _pickMonth,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.calendar_today, size: 18, color: AppTheme.primaryGold),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat('MMMM yyyy').format(_selectedMonth),
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const Icon(Icons.arrow_drop_down, color: AppTheme.primaryGold),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Search by name
                      TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Search by name...',
                          hintStyle: TextStyle(color: AppTheme.textSecondary.withOpacity(0.5)),
                          prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, color: AppTheme.textSecondary),
                                  onPressed: () {
                                    setState(() {
                                      _searchController.clear();
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value.toLowerCase();
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              // History list
              Expanded(
                child: StreamBuilder<List<ChaiRecordModel>>(
                  stream: _chaiService.getHistory(
                    groupId: provider.selectedGroup!.id,
                    month: _selectedMonth.month,
                    year: _selectedMonth.year,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error loading history',
                          style: TextStyle(color: AppTheme.textSecondary.withOpacity(0.8)),
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
                              size: 56,
                              color: AppTheme.textSecondary.withOpacity(0.5),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No records for ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.textSecondary.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final allRecords = snapshot.data!;
                    final memberIds = allRecords.map((r) => r.assignedTo).toSet().toList();

                    return FutureBuilder<Map<String, UserModel>>(
                      future: provider.getUsersById(memberIds),
                      builder: (context, usersSnapshot) {
                        final users = usersSnapshot.data ?? {};
                        
                        // Filter records by search query
                        final records = allRecords.where((record) {
                          if (_searchQuery.isEmpty) return true;
                          final userName = users[record.assignedTo]?.name.toLowerCase() ?? '';
                          return userName.contains(_searchQuery);
                        }).toList();

                        if (records.isEmpty) {
                          return Center(
                            child: Text(
                              'No results for "$_searchQuery"',
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: records.length,
                          itemBuilder: (context, index) {
                            final record = records[index];
                            final userName = users[record.assignedTo]?.name ?? 'Unknown';

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: GlassCard(
                                padding: const EdgeInsets.all(14),
                                borderRadius: BorderRadius.circular(16),
                                opacity: 0.05,
                                child: Row(
                                children: [
                                  // Status icon
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: record.isDone
                                          ? AppTheme.success.withOpacity(0.2)
                                          : AppTheme.accentAmber.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      record.isDone ? Icons.check_circle : Icons.pending,
                                      color: record.isDone ? AppTheme.success : AppTheme.accentAmber,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Details
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
                                        const SizedBox(height: 2),
                                        Text(
                                          DateFormat('EEE, MMM d').format(record.assignedDate),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textSecondary.withOpacity(0.8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Status badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: record.isDone
                                          ? AppTheme.success.withOpacity(0.1)
                                          : AppTheme.accentAmber.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: record.isDone 
                                            ? AppTheme.success.withOpacity(0.3)
                                            : AppTheme.accentAmber.withOpacity(0.3)
                                      ),
                                    ),
                                    child: Text(
                                      record.isDone ? 'Done' : 'Pending',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: record.isDone ? AppTheme.success : AppTheme.accentAmber,
                                      ),
                                    ),
                                  ),
                                  // Actions menu
                                  PopupMenuButton<String>(
                                    icon: Icon(Icons.more_vert, size: 20, color: AppTheme.textSecondary.withOpacity(0.7)),
                                    onSelected: (value) async {
                                      if (value == 'toggle') {
                                        try {
                                          if (record.isDone) {
                                            await _chaiService.markAsPending(record.id);
                                          } else {
                                            await _chaiService.markAsDone(
                                              recordId: record.id,
                                              broughtBy: record.assignedTo,
                                            );
                                          }
                                        } catch (e) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
                                            );
                                          }
                                        }
                                      } else if (value == 'delete') {
                                        _showDeleteRecordDialog(context, record.id);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      PopupMenuItem(
                                        value: 'toggle',
                                        child: Row(children: [
                                          Icon(record.isDone ? Icons.undo : Icons.check, size: 18),
                                          const SizedBox(width: 8),
                                          Text(record.isDone ? 'Mark Pending' : 'Mark Done'),
                                        ]),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(children: [
                                          Icon(Icons.delete, size: 18, color: AppTheme.error),
                                          SizedBox(width: 8),
                                          Text('Delete', style: TextStyle(color: AppTheme.error)),
                                        ]),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ));
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
