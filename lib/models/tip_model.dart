import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Categorías válidas que Gemini puede devolver en el campo "categoria".
/// El enum es la fuente de verdad — ni la view ni el controller comparan strings.
enum TipCategoria {
  nutricion,
  actividadFisica,
  bienestarMental,
  sueno,
  hidratacion,
  prevencion,
  medicacion,
}

extension TipCategoriaX on TipCategoria {
  /// Nombre visible en la UI.
  String get label => switch (this) {
        TipCategoria.nutricion => 'Nutrición',
        TipCategoria.actividadFisica => 'Actividad física',
        TipCategoria.bienestarMental => 'Bienestar mental',
        TipCategoria.sueno => 'Sueño',
        TipCategoria.hidratacion => 'Hidratación',
        TipCategoria.prevencion => 'Prevención',
        TipCategoria.medicacion => 'Medicación',
      };

  /// Ícono Material para mostrar junto al label.
  IconData get icon => switch (this) {
        TipCategoria.nutricion => Icons.restaurant_outlined,
        TipCategoria.actividadFisica => Icons.directions_run_rounded,
        TipCategoria.bienestarMental => Icons.self_improvement_rounded,
        TipCategoria.sueno => Icons.bedtime_outlined,
        TipCategoria.hidratacion => Icons.water_drop_outlined,
        TipCategoria.prevencion => Icons.health_and_safety_outlined,
        TipCategoria.medicacion => Icons.medication_outlined,
      };

  /// Convierte el string que devuelve Gemini ("actividad_fisica") al enum.
  /// Devuelve [TipCategoria.prevencion] como fallback si el valor es desconocido.
  static TipCategoria fromGeminiString(String raw) => switch (raw.trim().toLowerCase()) {
        'nutricion' => TipCategoria.nutricion,
        'actividad_fisica' => TipCategoria.actividadFisica,
        'bienestar_mental' => TipCategoria.bienestarMental,
        'sueno' => TipCategoria.sueno,
        'hidratacion' => TipCategoria.hidratacion,
        'prevencion' => TipCategoria.prevencion,
        'medicacion' => TipCategoria.medicacion,
        _ => TipCategoria.prevencion,
      };

  /// String que se persiste en Firestore (coincide con el contrato de Gemini).
  String get firestoreKey => switch (this) {
        TipCategoria.nutricion => 'nutricion',
        TipCategoria.actividadFisica => 'actividad_fisica',
        TipCategoria.bienestarMental => 'bienestar_mental',
        TipCategoria.sueno => 'sueno',
        TipCategoria.hidratacion => 'hidratacion',
        TipCategoria.prevencion => 'prevencion',
        TipCategoria.medicacion => 'medicacion',
      };
}

class TipModel {
  const TipModel({
    required this.id,
    required this.texto,
    required this.categoria,
    required this.fecha,
    required this.generadoPor,
    required this.uid,
  });

  final String id;
  final String texto;
  final TipCategoria categoria;
  final DateTime fecha;

  /// 'gemini' | 'manual'
  final String generadoPor;
  final String uid;

  factory TipModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TipModel(
      id: doc.id,
      texto: data['texto'] as String? ?? '',
      categoria: TipCategoriaX.fromGeminiString(data['categoria'] as String? ?? ''),
      fecha: (data['fecha'] as Timestamp).toDate(),
      generadoPor: data['generadoPor'] as String? ?? 'gemini',
      uid: data['uid'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'texto': texto,
        'categoria': categoria.firestoreKey,
        'fecha': Timestamp.fromDate(fecha),
        'generadoPor': generadoPor,
        'uid': uid,
      };
}
