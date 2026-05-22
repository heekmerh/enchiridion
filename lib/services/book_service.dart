import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/book.dart';

class BookService {
  static Future<Book> loadBook([String dataFile = 'assets/data/book.json']) async {
    try {
      final String jsonString = await rootBundle.loadString(dataFile);

      // Parse the JSON
      final Map<String, dynamic> jsonData = json.decode(jsonString);

      // Convert to Book object
      return Book.fromJson(jsonData);
    } catch (e) {
      // If loading fails, throw an error with details
      throw Exception('Failed to load book data: $e');
    }
  }
}
