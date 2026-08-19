import 'dart:convert';
import 'package:http/http.dart' as http;

class DevotionalService {
  static const String _clave = 'ef57c7734951ac3182e6b5a49fe9077532b600b0af7b1bf5e80076ceaf06ccb4';
  static const String _endpointAuth = 'https://templobetel.vercel.app/api/devotional-auth';
  static const String _firebaseApiKey = 'AIzaSyAW2Ow7zktdFKFeCbpPOK6TFbZsFqG3Wfo';
  static const String _projectId = 'betel-notes';

  String? _idToken;
  DateTime? _tokenExpiry;

  /// Obtiene el token de sesión y lo renueva si expiró
  Future<String> _obtenerTokenValido() async {
    if (_idToken != null && _tokenExpiry != null && DateTime.now().isBefore(_tokenExpiry!)) {
      return _idToken!;
    }

    // 1. Solicitar Custom Token al endpoint de Vercel
    final resVercel = await http.post(
      Uri.parse(_endpointAuth),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'action': 'reader', 'key': _clave}),
    );

    if (resVercel.statusCode != 200) {
      throw Exception('Error auth Vercel (${resVercel.statusCode}): ${resVercel.body}');
    }

    final dataVercel = jsonDecode(resVercel.body) as Map<String, dynamic>;
    final String customToken = dataVercel['token'];

    // 2. Canjear Custom Token por ID Token de Firebase
    final resFirebase = await http.post(
      Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=$_firebaseApiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'token': customToken, 'returnSecureToken': true}),
    );

    if (resFirebase.statusCode != 200) {
      throw Exception('Error login Firebase (${resFirebase.statusCode}): ${resFirebase.body}');
    }

    final dataFirebase = jsonDecode(resFirebase.body) as Map<String, dynamic>;
    _idToken = dataFirebase['idToken'];
    final int expiresIn = int.tryParse(dataFirebase['expiresIn']?.toString() ?? '3600') ?? 3600;
    _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn - 60));

    return _idToken!;
  }

  /// Lee el índice de capítulos disponibles
  Future<Map<String, dynamic>?> leerIndice() async {
    return _obtenerDocumento('devotionalBible', '_index');
  }

  /// Lee el plan del mes (ej: anio = 2026, mes = 8)
  Future<Map<String, dynamic>?> leerPlanMes(int anio, int mes) async {
    final String docId = '$anio-${mes.toString().padLeft(2, '0')}';
    return _obtenerDocumento('devotionalPlan', docId);
  }

  /// Lee un capítulo específico (ej: "Génesis", 1)
  Future<Map<String, dynamic>?> leerCapitulo(String libro, int capitulo) async {
    final String docId = _idCapitulo(libro, capitulo);
    return _obtenerDocumento('devotionalBible', docId);
  }

  /// Petición interna a la API REST de Firestore
  Future<Map<String, dynamic>?> _obtenerDocumento(String coleccion, String docId) async {
    final token = await _obtenerTokenValido();
    final url = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/$coleccion/$docId',
    );

    final res = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) {
      throw Exception('Error Firestore (${res.statusCode}): ${res.body}');
    }

    final Map<String, dynamic> json = jsonDecode(res.body);
    return _convertirCamposFirestore(json['fields'] as Map<String, dynamic>?);
  }

  /// Transforma los tipos de datos en formato Firestore REST a un Map estándar de Dart
  Map<String, dynamic> _convertirCamposFirestore(Map<String, dynamic>? fields) {
    if (fields == null) return {};
    final Map<String, dynamic> resultado = {};

    fields.forEach((clave, valor) {
      if (valor is Map<String, dynamic>) {
        if (valor.containsKey('stringValue')) resultado[clave] = valor['stringValue'];
        else if (valor.containsKey('integerValue')) resultado[clave] = int.tryParse(valor['integerValue']);
        else if (valor.containsKey('doubleValue')) resultado[clave] = valor['doubleValue'];
        else if (valor.containsKey('booleanValue')) resultado[clave] = valor['booleanValue'];
        else if (valor.containsKey('mapValue')) {
          resultado[clave] = _convertirCamposFirestore(valor['mapValue']['fields'] as Map<String, dynamic>?);
        } else if (valor.containsKey('arrayValue')) {
          final List valores = valor['arrayValue']['values'] ?? [];
          resultado[clave] = valores.map((v) {
            if (v is Map<String, dynamic> && v.containsKey('stringValue')) return v['stringValue'];
            return v;
          }).toList();
        } else {
          resultado[clave] = valor;
        }
      }
    });

    return resultado;
  }

  /// Convierte "Génesis" y 1 a "genesis-1"
  String _idCapitulo(String libro, int capitulo) {
    String slug = libro.toLowerCase().trim();
    const acentos = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u'};
    acentos.forEach((k, v) => slug = slug.replaceAll(k, v));
    slug = slug.replaceAll(RegExp(r'\s+'), '-');
    return '$slug-$capitulo';
  }
}