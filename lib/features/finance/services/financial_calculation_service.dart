import 'dart:async';
import 'package:fs_hub/features/finance/services/expense_service.dart';
import 'package:fs_hub/features/projects/services/project_service.dart';
import 'package:fs_hub/features/finance/services/credit_service.dart';
import 'package:fs_hub/features/clients/services/client_service.dart';
import 'package:fs_hub/shared/models/project_model.dart';
import 'package:fs_hub/features/clients/models/client_model.dart';

class FinancialCalculationService {
  static Future<Map<String, dynamic>> calculateProjectFinancialSummary(int projectId) async {
    try {
      // Récupérer toutes les données financières du projet
      final expenses = await ExpenseService.getAllProjectExpenses(projectId: projectId);
      final project = await ProjectService.getProjectById(projectId);
      final credits = await CreditService.getProjectCredits(projectId);
      
      if (project == null) {
        return {
          'success': false,
          'message': 'Project not found',
          'data': null,
        };
      }

      // Calculer les totaux
      final totalExpenses = expenses.fold(0.0, (sum, expense) => sum + (expense['montant'] as num).toDouble());
      final totalCredits = credits.fold(0.0, (sum, credit) => sum + (credit['montant'] as num).toDouble());
      final estimation = project.budget;
      
      // Calculer les indicateurs financiers
      final remainingBudget = estimation - totalExpenses;
      final profitMargin = estimation > 0 ? ((estimation - totalExpenses) / estimation) * 100 : 0.0;
      final expenseRatio = estimation > 0 ? (totalExpenses / estimation) * 100 : 0.0;
      
      // Calculer le statut financier
      String financialStatus = 'healthy';
      if (totalExpenses > estimation) {
        financialStatus = 'over_budget';
      } else if (expenseRatio > 80) {
        financialStatus = 'warning';
      } else if (expenseRatio > 60) {
        financialStatus = 'caution';
      }
      
      // Calculer les dépenses par catégorie
      final expensesByCategory = <String, double>{};
      for (final expense in expenses) {
        final category = expense['categorie'] as String? ?? 'Non catégorisé';
        expensesByCategory[category] = (expensesByCategory[category] ?? 0) + (expense['montant'] as double);
      }
      
      // Calculer les tendances (basé sur les 30 derniers jours)
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final recentExpenses = expenses.where((expense) {
        final expenseDate = DateTime.parse(expense['date_depense']);
        return expenseDate.isAfter(thirtyDaysAgo);
      }).toList();
      
      final recentTotal = recentExpenses.fold(0.0, (sum, expense) => sum + (expense['montant'] as double));
      final monthlyAverage = recentTotal * 2; // Estimation mensuelle basée sur 30 jours
      
      return {
        'success': true,
        'data': {
          'project_id': projectId,
          'project_name': project.nom,
          'estimation_budget': estimation,
          'total_expenses': totalExpenses,
          'total_credits': totalCredits,
          'remaining_budget': remainingBudget,
          'profit_margin': profitMargin,
          'expense_ratio': expenseRatio,
          'financial_status': financialStatus,
          'expenses_by_category': expensesByCategory,
          'recent_expenses_total': recentTotal,
          'monthly_expense_average': monthlyAverage,
          'total_transactions': expenses.length + credits.length,
          'last_updated': DateTime.now().toIso8601String(),
        },
        'message': 'Financial summary calculated successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error calculating financial summary: $e',
        'data': null,
      };
    }
  }

  static Future<Map<String, dynamic>> calculateCompanyFinancialSummary() async {
    try {
      // Récupérer toutes les dépenses de la société
      final expenses = await ExpenseService.getAllCompanyExpenses();
      
      // Calculer les totaux par catégorie
      final expensesByCategory = <String, double>{};
      final expensesByMonth = <String, List<Map<String, dynamic>>>{};
      
      for (final expense in expenses) {
        final category = expense['categorie'] as String? ?? 'Non catégorisé';
        final date = DateTime.parse(expense['date_depense']);
        final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
        
        expensesByCategory[category] = (expensesByCategory[category] ?? 0) + (expense['montant'] as double);
        
        if (!expensesByMonth.containsKey(monthKey)) {
          expensesByMonth[monthKey] = [];
        }
        expensesByMonth[monthKey]!.add(expense);
      }
      
      // Calculer les totaux mensuels
      final monthlyTotals = <String, double>{};
      expensesByMonth.forEach((month, expensesList) {
        monthlyTotals[month] = expensesList.fold(0.0, (sum, expense) => sum + (expense['montant'] as double));
      });
      
      // Calculer les tendances
      final totalExpenses = expenses.fold(0.0, (sum, expense) => sum + (expense['montant'] as double));
      final averageMonthly = monthlyTotals.isNotEmpty 
          ? monthlyTotals.values.reduce((a, b) => a + b) / monthlyTotals.length 
          : 0.0;
      
      // Identifier les catégories les plus coûteuses
      final sortedCategories = expensesByCategory.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      final topCategories = sortedCategories.take(5).map((entry) => {
        'category': entry.key,
        'amount': entry.value,
        'percentage': totalExpenses > 0 ? (entry.value / totalExpenses) * 100 : 0.0,
      }).toList();
      
      return {
        'success': true,
        'data': {
          'total_expenses': totalExpenses,
          'average_monthly': averageMonthly,
          'expenses_by_category': expensesByCategory,
          'monthly_totals': monthlyTotals,
          'top_expense_categories': topCategories,
          'total_transactions': expenses.length,
          'last_updated': DateTime.now().toIso8601String(),
        },
        'message': 'Company financial summary calculated successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error calculating company financial summary: $e',
        'data': null,
      };
    }
  }

  static Future<Map<String, dynamic>> calculateClientFinancialSummary(int clientId) async {
    try {
      // Récupérer les informations du client, ses projets et ses crédits (paiements)
      final response = await ClientService.getClientById(clientId);
      final credits = await CreditService.getClientCredits(clientId);
      final allProjects = await ProjectService.getAllProjects();
      final clientProjects = allProjects.where((p) => p.clientId == clientId).toList();
      
      if (response['success'] != true) {
        return {
          'success': false,
          'message': response['error'] ?? 'Client not found',
          'data': null,
        };
      }
      
      final client = response['data'] as Client;
      
      // Calculer les totaux
      // totalPaid = somme de tous les crédits (paiements) reçus du client
      final totalPaid = credits.fold(0.0, (sum, credit) => sum + (credit['montant'] as num).toDouble());
      
      // totalInvoiced = somme des budgets de tous les projets du client
      final totalInvoiced = clientProjects.fold(0.0, (sum, project) => sum + project.budget);
      
      final outstandingBalance = totalInvoiced - totalPaid;
      
      // Calculer les indicateurs
      // paymentRatio = pourcentage de la somme totale payée par rapport au budget total des projets
      final paymentRatio = totalInvoiced > 0 ? (totalPaid / totalInvoiced) * 100 : 0.0;
      
      // Déterminer le statut du client basé sur le recouvrement
      String clientStatus = 'active';
      if (paymentRatio >= 95) {
        clientStatus = 'excellent';
      } else if (paymentRatio >= 80) {
        clientStatus = 'good';
      } else if (paymentRatio >= 60) {
        clientStatus = 'average';
      } else if (paymentRatio >= 40) {
        clientStatus = 'poor';
      } else {
        clientStatus = 'critical';
      }
      
      return {
        'success': true,
        'data': {
          'client_id': clientId,
          'client_name': client.displayName,
          'total_invoiced': totalInvoiced,
          'total_paid': totalPaid,
          'outstanding_balance': outstandingBalance > 0 ? outstandingBalance : 0.0,
          'total_credits': totalPaid, // On utilise totalPaid car "crédit" = somme payée selon l'utilisateur
          'payment_ratio': paymentRatio,
          'client_status': clientStatus,
          'last_updated': DateTime.now().toIso8601String(),
        },
        'message': 'Client financial summary calculated successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error calculating client financial summary: $e',
        'data': null,
      };
    }
  }

  static Future<Map<String, dynamic>> calculateProfitabilityAnalysis(int projectId) async {
    try {
      final projectSummary = await calculateProjectFinancialSummary(projectId);
      
      if (!projectSummary['success']) {
        return projectSummary;
      }
      
      final data = projectSummary['data'] as Map<String, dynamic>;
      
      // Calculer la rentabilité
      final estimation = data['estimation_budget'] as double;
      final totalExpenses = data['total_expenses'] as double;
      final remainingBudget = data['remaining_budget'] as double;
      
      // Calculer le point mort (break-even)
      final breakEvenPoint = estimation > 0 ? (estimation * 0.8) : 0.0; // 80% du budget estimé
      
      // Calculer l'efficacité des dépenses
      final efficiency = estimation > 0 ? ((estimation - totalExpenses) / estimation) * 100 : 0.0;
      
      // Recommandations basées sur les calculs
      List<String> recommendations = [];
      
      if (totalExpenses > estimation) {
        recommendations.add('URGENT: Le projet dépasse le budget estimé');
      } else if (data['expense_ratio'] > 85) {
        recommendations.add('ATTENTION: Les dépenses approchent 85% du budget');
      }
      
      if (data['monthly_expense_average'] > estimation / 6) {
        recommendations.add('ALERT: La moyenne mensuelle des dépenses est élevée');
      }
      
      if (efficiency < 20) {
        recommendations.add('REVIEW: L\'efficacité du projet est faible (< 20%)');
      }
      
      return {
        'success': true,
        'data': {
          ...data,
          'break_even_point': breakEvenPoint,
          'efficiency': efficiency,
          'profitability_score': efficiency,
          'recommendations': recommendations,
          'risk_level': _calculateRiskLevel(data),
        },
        'message': 'Profitability analysis completed successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error calculating profitability analysis: $e',
        'data': null,
      };
    }
  }

  static String _calculateRiskLevel(Map<String, dynamic> projectData) {
    final expenseRatio = projectData['expense_ratio'] as double;
    final remainingBudget = projectData['remaining_budget'] as double;
    final estimation = projectData['estimation_budget'] as double;
    
    if (expenseRatio > 100 || remainingBudget < 0) {
      return 'critical';
    } else if (expenseRatio > 85) {
      return 'high';
    } else if (expenseRatio > 70) {
      return 'medium';
    } else if (expenseRatio > 50) {
      return 'low';
    } else {
      return 'minimal';
    }
  }

  static Future<Map<String, dynamic>> generateFinancialReport(int projectId) async {
    try {
      final projectSummary = await calculateProjectFinancialSummary(projectId);
      final profitabilityAnalysis = await calculateProfitabilityAnalysis(projectId);
      
      if (!projectSummary['success']) {
        return projectSummary;
      }
      
      final data = projectSummary['data'] as Map<String, dynamic>;
      
      // Générer le rapport financier complet
      final report = {
        'executive_summary': {
          'project_name': data['project_name'],
          'financial_status': data['financial_status'],
          'risk_level': profitabilityAnalysis['data']['risk_level'],
          'key_metrics': {
            'budget_estimation': data['estimation_budget'],
            'total_expenses': data['total_expenses'],
            'remaining_budget': data['remaining_budget'],
            'profit_margin': data['profit_margin'],
          },
        },
        'detailed_analysis': {
          'expenses_breakdown': data['expenses_by_category'],
          'monthly_trends': data['monthly_expense_average'],
          'efficiency_metrics': profitabilityAnalysis['data']['efficiency'],
          'break_even_analysis': profitabilityAnalysis['data']['break_even_point'],
        },
        'recommendations': profitabilityAnalysis['data']['recommendations'],
        'generated_at': DateTime.now().toIso8601String(),
        'report_period': 'Last 30 days',
      };
      
      return {
        'success': true,
        'data': report,
        'message': 'Financial report generated successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error generating financial report: $e',
        'data': null,
      };
    }
  }

  static Future<Map<String, dynamic>> calculateBudgetForecast(int projectId, int months) async {
    try {
      final projectSummary = await calculateProjectFinancialSummary(projectId);
      
      if (!projectSummary['success']) {
        return projectSummary;
      }
      
      final data = projectSummary['data'] as Map<String, dynamic>;
      final monthlyAverage = data['monthly_expense_average'] as double;
      
      // Générer des prévisions pour les prochains mois
      final forecast = <Map<String, dynamic>>[];
      DateTime currentDate = DateTime.now();
      
      for (int i = 1; i <= months; i++) {
        final forecastDate = DateTime(currentDate.year, currentDate.month + i, 1);
        final monthKey = '${forecastDate.year}-${forecastDate.month.toString().padLeft(2, '0')}';
        
        // Principe: les dépenses ont tendance à augmenter de 5% par mois
        final projectedExpense = monthlyAverage * (1 + (0.05 * i));
        final cumulativeExpense = monthlyAverage * i * (1 + (0.025 * (i + 1))); // Formule de progression
        
        forecast.add({
          'month': monthKey,
          'projected_expense': projectedExpense,
          'cumulative_expense': cumulativeExpense,
          'confidence_level': i <= 3 ? 'high' : i <= 6 ? 'medium' : 'low',
        });
      }
      
      return {
        'success': true,
        'data': {
          'project_id': projectId,
          'forecast_period_months': months,
          'current_monthly_average': monthlyAverage,
          'forecast': forecast,
          'total_projected_expense': forecast.last['cumulative_expense'],
          'generated_at': DateTime.now().toIso8601String(),
        },
        'message': 'Budget forecast generated successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error generating budget forecast: $e',
        'data': null,
      };
    }
  }
}
