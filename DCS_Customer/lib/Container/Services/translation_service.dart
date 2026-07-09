import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appLanguageProvider = StateNotifierProvider<LanguageNotifier, String>((ref) {
  return LanguageNotifier();
});

class LanguageNotifier extends StateNotifier<String> {
  LanguageNotifier() : super('en') {
    _loadSavedLanguage();
  }

  Future<void> _loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString('app_language') ?? 'en';
  }

  Future<void> setLanguage(String langCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', langCode);
    state = langCode;
  }
}

class TranslationService {
  // Simple memory cache to prevent redundant API calls and UI flickering
  static final Map<String, String> _cache = {};

  static Future<String> translate(String text, String targetLang) async {
    if (targetLang == 'en' || text.isEmpty) return text;

    final cacheKey = '${text}_$targetLang';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    try {
      final url = Uri.parse(
          'https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=$targetLang&dt=t&q=${Uri.encodeComponent(text)}');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        String translatedText = '';
        for (var i = 0; i < jsonResponse[0].length; i++) {
          translatedText += jsonResponse[0][i][0];
        }
        _cache[cacheKey] = translatedText;
        return translatedText;
      }
    } catch (e) {
      print("Translation error: $e");
    }
    return text; // Fallback to English
  }
}

// Map of all major Indian Languages
const Map<String, String> indianLanguages = {
  'en': 'English',
  'hi': 'हिंदी (Hindi)',
  'bn': 'বাংলা (Bengali)',
  'te': 'తెలుగు (Telugu)',
  'mr': 'मराठी (Marathi)',
  'ta': 'தமிழ் (Tamil)',
  'ur': 'اردو (Urdu)',
  'gu': 'ગુજરાતી (Gujarati)',
  'kn': 'ಕನ್ನಡ (Kannada)',
  'or': 'ଓଡ଼ିଆ (Odia)',
  'ml': 'മലയാളം (Malayalam)',
  'pa': 'ਪੰਜਾਬੀ (Punjabi)',
  'as': 'অসমীয়া (Assamese)',
};
