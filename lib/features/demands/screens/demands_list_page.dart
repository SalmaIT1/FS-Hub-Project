import 'package:flutter/material.dart';
import 'dart:ui';
import '../../../shared/models/demand_model.dart';
import '../services/demand_service.dart';
import '../../../widgets/demand_card.dart';
import '../../../shared/widgets/luxury/luxury_app_bar.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/data/services/auth_service.dart';
import '../../../core/routes/app_routes.dart';
import 'package:provider/provider.dart';
import 'demand_detail_page.dart';

class DemandsListPage extends StatefulWidget {
  const DemandsListPage({super.key});

  @override
  State<DemandsListPage> createState() => _DemandsListPageState();
}

class _DemandsListPageState extends State<DemandsListPage> {
  List<Demand> _demands = [];
  bool _isLoading = true;
  String _selectedStatus = 'all';
  String _selectedType = 'all';
  String? _currentUserId;
  String? _currentUserRole;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = await AuthService.getCurrentUser();
      if (user != null && mounted) {
        setState(() {
          _currentUserId = user['id'];
          _currentUserRole = user['role'];
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
    _loadDemands();
  }

  Future<void> _loadDemands() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await DemandService.getAllDemands(
        status: _selectedStatus == 'all' ? null : _selectedStatus,
        type: _selectedType == 'all' ? null : _selectedType,
      );

      if (result['success'] && mounted) {
        final data = result['data'] as Map<String, dynamic>;
        if (data['success'] && data['data'] != null) {
          final demandsList = data['data'] as List;
          setState(() {
            _demands = demandsList
                .map((json) => Demand.fromJson(json as Map<String, dynamic>))
                .toList();
            _isLoading = false;
          });
        } else {
          setState(() {
            _demands = [];
            _isLoading = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(data['message'] ?? 'Failed to load demands')),
            );
          }
        }
      } else {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'Failed to load demands')),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading demands: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: LuxuryAppBar(
        title: 'Demands & Requests',
        subtitle: 'Manage and track all system demands',
        showBackButton: true,
        onBackPress: () => Navigator.pop(context),
        isPremium: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.8, -0.8),
            radius: 1.2,
            colors: isDark 
                ? [const Color(0xFF1A1A1A), Colors.black]
                : [const Color(0xFFF5F5F7), const Color(0xFFE8E8EA)],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _loadDemands,
          child: Column(
            children: [
              // Demands list
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _demands.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.assignment_outlined,
                                  size: 64,
                                  color: isDark ? Colors.white38 : Colors.black26,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No demands found',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: isDark ? Colors.white70 : Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Create your first demand to get started',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark ? Colors.white54 : Colors.black38,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _demands.length,
                            itemBuilder: (context, index) {
                              return DemandCard(
                                demand: _demands[index],
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => DemandDetailPage(demand: _demands[index]),
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
      ),
    );
  }
}