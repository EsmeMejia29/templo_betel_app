import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/reading_model.dart';

class ReadingService {
  final _supabase = Supabase.instance.client;

  /// Registra o elimina el progreso de una lectura en Supabase
  Future<void> toggleReadingStatus(DevotionalReading reading) async {
    // 1. Obtener el usuario autenticado actualmente
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception("No hay ningún usuario autenticado.");

    final profileId = user.id;

    try {
      // Como el estado local cambia después, aquí verificamos el estado previo.
      // Si NO estaba completada, significa que el usuario la quiere marcar como COMPLETADA ahora.
      if (!reading.isCompleted) {
        // Guardar en la tabla intermedia 'user_progress'
        await _supabase.from('user_progress').insert({
          'profile_id': profileId,
          'reading_id': reading.id,
          'completed_at': DateTime.now().toIso8601String(),
        });
      } else {
        // Si YA estaba completada, significa que el usuario la quiere DESMARCAR.
        await _supabase
            .from('user_progress')
            .delete()
            .match({
              'profile_id': profileId,
              'reading_id': reading.id,
            });
      }
    } catch (e) {
      print("Error actualizando progreso en Supabase: $e");
      rethrow;
    }
  }
}