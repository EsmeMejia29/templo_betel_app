import 'dart:convert';
import 'package:http/http.dart' as http;

class AIService {
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  static Future<Map<String, String>> extraerVersiculoClave(String chapterContent) async {
    if (_apiKey.isEmpty) {
      return {'versiculo': '', 'referencia': '', 'error': 'API Key no configurada.'};
    }

    try {
      final url = Uri.parse('$_baseUrl?key=$_apiKey');

      final prompt = """
Analiza el siguiente capítulo de la Biblia. Identifica el versículo más importante o representativo de todo el texto provisto.
Es estrictamente obligatorio que en la referencia incluyas el libro, el capítulo y el número exacto del versículo identificado (por ejemplo: "Génesis 1:1" o "1 Crónicas 1:34"). No omitas el número de versículo por ningún motivo.
Devuelve la respuesta única y estrictamente en este formato JSON:
{
  "versiculo": "Texto exacto del versículo seleccionado",
  "referencia": "Libro Capítulo:Versículo"
}
Texto del capítulo:
$chapterContent
""";

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [{'text': prompt}]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        String rawText = jsonResponse['candidates'][0]['content']['parts'][0]['text'];

        final int startIndex = rawText.indexOf('{');
        final int endIndex = rawText.lastIndexOf('}');

        if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
          rawText = rawText.substring(startIndex, endIndex + 1);
        }

        final Map<String, dynamic> data = jsonDecode(rawText);

        return {
          'versiculo': data['versiculo'] ?? '',
          'referencia': data['referencia'] ?? '',
          'error': '',
        };
      } else {
        return {
          'versiculo': '',
          'referencia': '',
          'error': 'Código ${response.statusCode}: ${response.body}'
        };
      }
    } catch (e) {
      return {
        'versiculo': '',
        'referencia': '',
        'error': 'Error local: $e'
      };
    }
  }

  static Future<Map<String, dynamic>> generarCuestionario(String chapterContent, String bookAndChapter) async {
    if (_apiKey.isEmpty) {
      return {'preguntas': [], 'error': 'API Key no configurada.'};
    }

    try {
      final url = Uri.parse('$_baseUrl?key=$_apiKey');

      final prompt = """
Eres un maestro bíblico didáctico y divertido. Crea un cuestionario de recapitulación de 3 preguntas de opción múltiple basado exclusivamente en el siguiente texto de la Biblia correspondiente a $bookAndChapter.
Reglas estrictas:
1. Cada pregunta debe tener exactamente 4 opciones de respuesta.
2. Indica en 'respuesta_correcta' el índice numérico (0, 1, 2 o 3) de la opción que es correcta.
3. Añade una 'explicacion' breve explicando por qué esa es la respuesta según el texto bíblico.
4. Devuelve única y estrictamente un objeto JSON con este formato (sin markdown adicional):
{
  "preguntas": [
    {
      "pregunta": "¿Texto de la pregunta?",
      "opciones": ["Opción A", "Opción B", "Opción C", "Opción D"],
      "respuesta_correcta": 0,
      "explicacion": "Breve explicación basada en el capítulo."
    }
  ]
}
Texto del capítulo bíblico:
$chapterContent
""";

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [{'text': prompt}]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        String rawText = jsonResponse['candidates'][0]['content']['parts'][0]['text'];

        final int startIndex = rawText.indexOf('{');
        final int endIndex = rawText.lastIndexOf('}');

        if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
          rawText = rawText.substring(startIndex, endIndex + 1);
        }

        final Map<String, dynamic> data = jsonDecode(rawText);
        return {
          'preguntas': data['preguntas'] ?? [],
          'error': '',
        };
      } else {
        return {
          'preguntas': [],
          'error': 'Código ${response.statusCode}: ${response.body}'
        };
      }
    } catch (e) {
      return {
        'preguntas': [],
        'error': 'Error al generar juego: $e'
      };
    }
  }
}