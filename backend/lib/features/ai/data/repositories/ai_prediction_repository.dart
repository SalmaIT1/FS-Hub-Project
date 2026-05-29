import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../../../shared/database/connection.dart';

class AIPredictionRepository {
  final _db = DBConnection.getConnection();

  Future<int?> savePrediction({
    required String modelName,
    required String modelVersion,
    required String entityType,
    required String entityId,
    required String predictionType,
    double? score,
    String? labelPredicted,
    double? confidence,
    Map<String, dynamic>? explanation,
    String? requestedBy,
    String inferenceMode = 'realtime',
  }) async {
    try {
      final result = await _db.execute('''
        INSERT INTO ai_predictions
          (model_name, model_version, entity_type, entity_id, prediction_type,
           score, label_predicted, confidence, explanation_json, requested_by, inference_mode)
        VALUES
          (:model, :version, :etype, :eid, :ptype,
           :score, :label, :conf, :expl, :user, :mode)
      ''', {
        'model': modelName,
        'version': modelVersion,
        'etype': entityType,
        'eid': entityId,
        'ptype': predictionType,
        'score': score,
        'label': labelPredicted,
        'conf': confidence,
        'expl': explanation != null ? jsonEncode(explanation) : null,
        'user': requestedBy,
        'mode': inferenceMode,
      });
      return result.lastInsertID.toInt();
    } catch (e) {
      print('AI PREDICTION SAVE ERROR: $e');
      return null;
    }
  }

  Future<void> saveFeatureSnapshot({
    required String entityType,
    required String entityId,
    required Map<String, dynamic> features,
    String featureVersion = 'v1',
  }) async {
    try {
      final json = jsonEncode(features);
      final hash = sha256.convert(utf8.encode(json)).toString();
      await _db.execute('''
        INSERT INTO ai_feature_snapshots
          (entity_type, entity_id, feature_version, features_json, feature_hash)
        VALUES (:etype, :eid, :ver, :feat, :hash)
      ''', {
        'etype': entityType,
        'eid': entityId,
        'ver': featureVersion,
        'feat': json,
        'hash': hash,
      });
    } catch (e) {
      print('AI FEATURE SNAPSHOT ERROR: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getRecentPredictions({
    String? entityType,
    String? predictionType,
    int limit = 50,
  }) async {
    var sql = '''
      SELECT id, model_name, model_version, entity_type, entity_id, prediction_type,
             score, label_predicted, confidence, explanation_json, created_at
      FROM ai_predictions
      WHERE 1=1
    ''';
    final params = <String, dynamic>{'lim': limit};

    if (entityType != null) {
      sql += ' AND entity_type = :etype';
      params['etype'] = entityType;
    }
    if (predictionType != null) {
      sql += ' AND prediction_type = :ptype';
      params['ptype'] = predictionType;
    }
    sql += ' ORDER BY created_at DESC LIMIT :lim';

    final result = await _db.execute(sql, params);
    return result.rows.map((row) {
      final m = row.assoc();
      if (m['explanation_json'] != null && m['explanation_json'].toString().isNotEmpty) {
        try {
          m['explanation'] = jsonDecode(m['explanation_json'].toString());
        } catch (_) {}
      }
      return m;
    }).toList();
  }

  Future<void> upsertKpi({
    required String kpiCode,
    required double value,
    String dimensionKey = 'global',
    Map<String, dynamic>? valueJson,
  }) async {
    try {
      await _db.execute('''
        INSERT INTO ai_kpi_daily (kpi_date, kpi_code, dimension_key, value_decimal, value_json)
        VALUES (CURDATE(), :code, :dim, :val, :json)
        ON DUPLICATE KEY UPDATE
          value_decimal = VALUES(value_decimal),
          value_json = VALUES(value_json)
      ''', {
        'code': kpiCode,
        'dim': dimensionKey,
        'val': value,
        'json': valueJson != null ? jsonEncode(valueJson) : null,
      });
    } catch (e) {
      print('AI KPI UPSERT ERROR: $e');
    }
  }
}
