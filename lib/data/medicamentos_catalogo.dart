// TODO: Ampliar esta lista con más medicamentos según necesidad clínica.
// Fuente de referencia: medicamentos de venta libre y prescripción frecuente en Perú (DIGEMID).

class MedicamentoCatalogo {
  const MedicamentoCatalogo({
    required this.nombre,
    required this.presentacion,
  });

  final String nombre;
  final String presentacion;

  String get nombreCompleto => '$nombre $presentacion';
}

const List<MedicamentoCatalogo> medicamentosCatalogo = [
  // ── Analgésicos / Antipiréticos ──────────────────────────────────────────
  MedicamentoCatalogo(nombre: 'Paracetamol', presentacion: 'tabletas'),
  MedicamentoCatalogo(nombre: 'Paracetamol', presentacion: 'jarabe'),
  MedicamentoCatalogo(nombre: 'Paracetamol', presentacion: 'gotas'),
  MedicamentoCatalogo(nombre: 'Paracetamol', presentacion: 'solución'),
  MedicamentoCatalogo(nombre: 'Ibuprofeno', presentacion: 'tabletas'),
  MedicamentoCatalogo(nombre: 'Ibuprofeno', presentacion: 'jarabe'),
  MedicamentoCatalogo(nombre: 'Ibuprofeno', presentacion: 'gotas'),
  MedicamentoCatalogo(nombre: 'Naproxeno', presentacion: 'tabletas'),
  MedicamentoCatalogo(nombre: 'Diclofenaco', presentacion: 'tabletas'),
  MedicamentoCatalogo(nombre: 'Diclofenaco', presentacion: 'inyección'),
  MedicamentoCatalogo(nombre: 'Ketorolaco', presentacion: 'tabletas'),
  MedicamentoCatalogo(nombre: 'Ketorolaco', presentacion: 'inyección'),
  MedicamentoCatalogo(nombre: 'Metamizol', presentacion: 'tabletas'),
  MedicamentoCatalogo(nombre: 'Metamizol', presentacion: 'inyección'),

  // ── Antibióticos ──────────────────────────────────────────────────────────
  MedicamentoCatalogo(nombre: 'Amoxicilina', presentacion: 'cápsulas'),
  MedicamentoCatalogo(nombre: 'Amoxicilina', presentacion: 'jarabe'),
  MedicamentoCatalogo(nombre: 'Azitromicina', presentacion: 'tabletas'),
  MedicamentoCatalogo(nombre: 'Azitromicina', presentacion: 'jarabe'),
  MedicamentoCatalogo(nombre: 'Ciprofloxacino', presentacion: 'tabletas'),
  MedicamentoCatalogo(nombre: 'Claritromicina', presentacion: 'tabletas'),
  MedicamentoCatalogo(nombre: 'Metronidazol', presentacion: 'tabletas'),

  // ── Antihistamínicos ──────────────────────────────────────────────────────
  MedicamentoCatalogo(nombre: 'Loratadina', presentacion: 'tabletas'),
  MedicamentoCatalogo(nombre: 'Loratadina', presentacion: 'jarabe'),
  MedicamentoCatalogo(nombre: 'Cetirizina', presentacion: 'tabletas'),
  MedicamentoCatalogo(nombre: 'Cetirizina', presentacion: 'jarabe'),
  MedicamentoCatalogo(nombre: 'Difenhidramina', presentacion: 'tabletas'),

  // ── Gastrointestinales ────────────────────────────────────────────────────
  MedicamentoCatalogo(nombre: 'Omeprazol', presentacion: 'cápsulas'),
  MedicamentoCatalogo(nombre: 'Omeprazol', presentacion: 'inyección'),
  MedicamentoCatalogo(nombre: 'Ranitidina', presentacion: 'tabletas'),
  MedicamentoCatalogo(nombre: 'Esomeprazol', presentacion: 'cápsulas'),
  MedicamentoCatalogo(nombre: 'Metoclopramida', presentacion: 'tabletas'),
  MedicamentoCatalogo(nombre: 'Metoclopramida', presentacion: 'inyección'),
  MedicamentoCatalogo(nombre: 'Dimenhidrinato', presentacion: 'tabletas'),
  MedicamentoCatalogo(nombre: 'Loperamida', presentacion: 'cápsulas'),
  MedicamentoCatalogo(nombre: 'Simeticona', presentacion: 'tabletas'),
  MedicamentoCatalogo(nombre: 'Simeticona', presentacion: 'gotas'),

  // ── Cardiovasculares / Hipertensión ───────────────────────────────────────
  MedicamentoCatalogo(nombre: 'Losartán', presentacion: 'tabletas'),
  MedicamentoCatalogo(nombre: 'Enalapril', presentacion: 'tabletas'),
  MedicamentoCatalogo(nombre: 'Amlodipino', presentacion: 'tabletas'),
  MedicamentoCatalogo(nombre: 'Atenolol', presentacion: 'tabletas'),
  MedicamentoCatalogo(nombre: 'Metoprolol', presentacion: 'tabletas'),
  MedicamentoCatalogo(nombre: 'Hidroclorotiazida', presentacion: 'tabletas'),

  // ── Diabetes ──────────────────────────────────────────────────────────────
  MedicamentoCatalogo(nombre: 'Metformina', presentacion: 'tabletas'),
  MedicamentoCatalogo(nombre: 'Glibenclamida', presentacion: 'tabletas'),
  MedicamentoCatalogo(nombre: 'Insulina NPH', presentacion: 'inyección'),
  MedicamentoCatalogo(nombre: 'Insulina regular', presentacion: 'inyección'),

  // ── Corticosteroides ──────────────────────────────────────────────────────
  MedicamentoCatalogo(nombre: 'Dexametasona', presentacion: 'tabletas'),
  MedicamentoCatalogo(nombre: 'Dexametasona', presentacion: 'inyección'),
  MedicamentoCatalogo(nombre: 'Prednisona', presentacion: 'tabletas'),
  MedicamentoCatalogo(nombre: 'Betametasona', presentacion: 'inyección'),

  // ── Vitaminas / Suplementos frecuentes ────────────────────────────────────
  MedicamentoCatalogo(nombre: 'Complejo B', presentacion: 'tabletas'),
  MedicamentoCatalogo(nombre: 'Vitamina C', presentacion: 'tabletas'),
  MedicamentoCatalogo(nombre: 'Vitamina D3', presentacion: 'cápsulas'),
  MedicamentoCatalogo(nombre: 'Hierro', presentacion: 'tabletas'),
  MedicamentoCatalogo(nombre: 'Ácido fólico', presentacion: 'tabletas'),
  MedicamentoCatalogo(nombre: 'Calcio + D3', presentacion: 'tabletas'),

  // ── Otros frecuentes ──────────────────────────────────────────────────────
  MedicamentoCatalogo(nombre: 'Atorvastatina', presentacion: 'tabletas'),
  MedicamentoCatalogo(nombre: 'Levotiroxina', presentacion: 'tabletas'),
  MedicamentoCatalogo(nombre: 'Salbutamol', presentacion: 'inhalador'),
  MedicamentoCatalogo(nombre: 'Alprazolam', presentacion: 'tabletas'),
  MedicamentoCatalogo(nombre: 'Clonazepam', presentacion: 'tabletas'),
];

/// Filtra el catálogo por el texto ingresado (nombre o presentación, sin distinguir mayúsculas).
List<MedicamentoCatalogo> filtrarMedicamentos(String query) {
  if (query.trim().isEmpty) return const [];
  final q = query.toLowerCase();
  return medicamentosCatalogo
      .where((m) =>
          m.nombre.toLowerCase().contains(q) ||
          m.presentacion.toLowerCase().contains(q))
      .toList();
}
