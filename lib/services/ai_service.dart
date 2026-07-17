import 'dart:convert';
import 'package:http/http.dart' as http;

class AIService {
  static const String _apiKey = 'AQ.Ab8RN6LC5paYRy4AYVXLC7h3Sj2hepMjCWGiwtZO8oBP4Vr7oA'; 
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  static Future<Map<String, String>> extraerVersiculoClave(String chapterContent) async {
    try {
      final url = Uri.parse('$_baseUrl?key=$_apiKey');

      final prompt = """
Analiza el siguiente capítulo de la Biblia. Identifica el versículo más importante, inspirador o representativo (versículo clave). 
Devuelve tu respuesta estrictamente en formato JSON con la siguiente estructura, sin texto adicional ni formateo de código (no uses bloques de Markdown como ```json):

{
  "versiculo": "El texto exacto del versículo encontrado...",
  "referencia": "La referencia exacta (ej. Salmos 23:1)"
}

Este es el texto del capítulo:
$chapterContent
""";

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final String rawText = jsonResponse['candidates'][0]['content']['parts'][0]['text'];
        
        final cleanText = rawText.replaceAll('```json', '').replaceAll('```', '').trim();
        final Map<String, dynamic> data = jsonDecode(cleanText);

        return {
          'versiculo': data['versiculo'] ?? '',
          'referencia': data['referencia'] ?? '',
        };
      } else {
        throw Exception('Error en la API de Gemini: ${response.statusCode}');
      }
    } catch (e) {
      print('Error al extraer versículo con IA: $e');
      return {
        'versiculo': 'No se pudo generar el versículo automáticamente.',
        'referencia': 'Error de IA'
      };
    }
  }
}