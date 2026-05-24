import 'package:flutter_test/flutter_test.dart';
import 'package:enchiridion/models/book.dart';
import 'package:enchiridion/models/chapter.dart';

void main() {
  group('Book', () {
    test('fromJson creates a valid Book object', () {
      final json = {
        'id': '1',
        'title': 'Test Book',
        'author': 'Test Author',
        'coverUrl': 'http://example.com/cover.jpg',
        'chapters': [
          {
            'chapter_metadata': {
              'chapter_id': 'c1',
              'chapter_title': 'Chapter 1',
              'position_in_book': 1,
            },
            'sections': [
              {
                'section_id': 'sec1',
                'section_title': 'Section 1',
                'section_order': 1,
                'subsections': [],
              }
            ]
          }
        ]
      };

      final book = Book.fromJson(json);

      expect(book.id, '1');
      expect(book.title, 'Test Book');
      expect(book.author, 'Test Author');
      expect(book.chapters.length, 1);
      expect(book.chapters.first.title, 'Chapter 1');
      expect(book.chapters.first.sections.length, 1);
    });

    test('toJson returns correct map', () {
      const chapter = Chapter(
        id: 'c1',
        title: 'Chapter 1',
        order: 1,
        sections: [
          ChapterSection(
            id: 'sec1',
            title: 'Section 1',
            order: 1,
            subsections: [],
          ),
        ],
      );
      const book = Book(
        id: '1',
        title: 'Test Book',
        author: 'Test Author',
        coverUrl: 'http://example.com/cover.jpg',
        chapters: [chapter],
      );

      final json = book.toJson();

      expect(json['id'], '1');
      expect(json['title'], 'Test Book');
      expect(json['chapters'], isA<List>());
      expect((json['chapters'] as List).length, 1);
      
      final chapterJson = (json['chapters'] as List)[0];
      expect(chapterJson['chapter_metadata']['chapter_id'], 'c1');
    });
  });
}
