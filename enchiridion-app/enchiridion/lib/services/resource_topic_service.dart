import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/chapter.dart';

class ResourceTopicService {
  static Future<Chapter> loadChapter(String assetPath) async {
    final jsonString = await rootBundle.loadString(assetPath);
    final jsonData = json.decode(jsonString) as Map<String, dynamic>;
    return Chapter.fromJson(jsonData);
  }
}
