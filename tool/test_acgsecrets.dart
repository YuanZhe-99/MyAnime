import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  print('=== SEASON PAGE JSON-LD ===');
  final seasonResp = await http.get(
    Uri.parse('https://acgsecrets.hk/bangumi/202601/'),
    headers: {'User-Agent': 'MyAnime/0.1'},
  );
  print('Status: ${seasonResp.statusCode}');
  final sBody = seasonResp.body;

  // Extract JSON-LD
  final ldPattern = RegExp(r'<script[^>]*type="application/ld\+json"[^>]*>(.*?)</script>', dotAll: true);
  for (final m in ldPattern.allMatches(sBody)) {
    final jsonStr = m.group(1)!;
    try {
      final data = jsonDecode(jsonStr);
      if (data is Map && data['itemListElement'] != null) {
        final items = data['itemListElement'] as List;
        print('Found ${items.length} anime entries!');
        // Print first 3 entries
        for (int i = 0; i < 3 && i < items.length; i++) {
          final item = items[i] as Map;
          print('\n--- Entry ${i + 1} ---');
          print('name: ${item['name']}');
          print('alternateName: ${item['alternateName']}');
          print('url: ${item['url']}');
          print('image: ${item['image']}');
          print('startDate: ${item['startDate']}');
          print('genre: ${item['genre']}');
          print('type: ${item['@type']}');
          print('numberOfSeasons: ${item['numberOfSeasons']}');
          print('numberOfEpisodes: ${item['numberOfEpisodes']}');
        }
      }
    } catch (e) {
      print('JSON parse error: $e');
      // Still show a snippet
      print('JSON snippet: ${jsonStr.substring(0, 500.clamp(0, jsonStr.length))}');
    }
  }

  // Also test: can we parse the HTML for anime_name divs?  
  print('\n\n=== HTML anime_name divs ===');
  final nameRegex = RegExp(r'<div class="anime_name">([^<]+)</div>');
  int count = 0;
  for (final m in nameRegex.allMatches(sBody)) {
    if (count++ >= 10) break;
    print('anime_name: ${m.group(1)}');
  }
}



