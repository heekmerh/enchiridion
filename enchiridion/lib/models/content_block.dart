
enum BlockType {
  mnemonic,
  table,
  checklist,
  clinicalPearls,
  redFlags,
  ageReference,
  algorithm,
  keyValue,
  paragraph,
  unknown
}

abstract class ContentBlock {
  final BlockType type;

  const ContentBlock({required this.type});

  factory ContentBlock.fromJson(Map<String, dynamic> json) {
    final String? typeStr = json['type'];
    
    if (typeStr == null) {
      // Fallback inference if type is missing
      if (json.containsKey('mnemonic')) return MnemonicBlock.fromJson(json);
      if (json.containsKey('columns')) return TableBlock.fromJson(json);
      if (json.containsKey('steps')) return AlgorithmBlock.fromJson(json);
      if (json.containsKey('age_unit')) return AgeReferenceBlock.fromJson(json);
      if (json.containsKey('text')) return ParagraphBlock.fromJson(json);
      return ParagraphBlock(text: '');
    }

    switch (typeStr) {
      case 'mnemonic': return MnemonicBlock.fromJson(json);
      case 'table': return TableBlock.fromJson(json);
      case 'checklist': return ChecklistBlock.fromJson(json);
      case 'clinical_pearls': return ClinicalPearlsBlock.fromJson(json);
      case 'red_flags': return RedFlagsBlock.fromJson(json);
      case 'age_reference': return AgeReferenceBlock.fromJson(json);
      case 'algorithm': return AlgorithmBlock.fromJson(json);
      case 'key_value': return KeyValueBlock.fromJson(json);
      case 'paragraph': return ParagraphBlock.fromJson(json);
      default: return ParagraphBlock.fromJson(json);
    }
  }

  Map<String, dynamic> toJson();
}

class MnemonicItem {
  final String key;
  final String label;
  final String? value;

  MnemonicItem({required this.key, required this.label, this.value});

  factory MnemonicItem.fromJson(Map<String, dynamic> json) {
    return MnemonicItem(
      key: json['key'] ?? '',
      label: json['label'] ?? '',
      value: json['value'],
    );
  }

  Map<String, dynamic> toJson() => {
    'key': key,
    'label': label,
    'value': value,
  };
}

class MnemonicBlock extends ContentBlock {
  final String mnemonic;
  final List<MnemonicItem> items;

  MnemonicBlock({required this.mnemonic, required this.items}) 
      : super(type: BlockType.mnemonic);

  factory MnemonicBlock.fromJson(Map<String, dynamic> json) {
    return MnemonicBlock(
      mnemonic: json['mnemonic'] ?? '',
      items: (json['items'] as List?)?.map((e) => MnemonicItem.fromJson(e)).toList() ?? [],
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'mnemonic',
    'mnemonic': mnemonic,
    'items': items.map((e) => e.toJson()).toList(),
  };
}

class TableBlock extends ContentBlock {
  final List<String> columns;
  final List<List<String>> rows;

  TableBlock({required this.columns, required this.rows}) 
      : super(type: BlockType.table);

  factory TableBlock.fromJson(Map<String, dynamic> json) {
    return TableBlock(
      columns: (json['columns'] as List?)?.map((e) => e.toString()).toList() ?? [],
      rows: (json['rows'] as List?)?.map((row) => 
        (row as List).map((cell) => cell.toString()).toList()
      ).toList() ?? [],
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'table',
    'columns': columns,
    'rows': rows,
  };
}

class ChecklistBlock extends ContentBlock {
  final String? title;
  final List<String> items;

  ChecklistBlock({this.title, required this.items}) 
      : super(type: BlockType.checklist);

  factory ChecklistBlock.fromJson(Map<String, dynamic> json) {
    return ChecklistBlock(
      title: json['title'],
      items: (json['items'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'checklist',
    'title': title,
    'items': items,
  };
}

class ClinicalPearlsBlock extends ContentBlock {
  final List<String> items;

  ClinicalPearlsBlock({required this.items}) 
      : super(type: BlockType.clinicalPearls);

  factory ClinicalPearlsBlock.fromJson(Map<String, dynamic> json) {
    return ClinicalPearlsBlock(
      items: (json['items'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'clinical_pearls',
    'items': items,
  };
}

class RedFlagsBlock extends ContentBlock {
  final List<String> items;

  RedFlagsBlock({required this.items}) 
      : super(type: BlockType.redFlags);

  factory RedFlagsBlock.fromJson(Map<String, dynamic> json) {
    return RedFlagsBlock(
      items: (json['items'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'red_flags',
    'items': items,
  };
}

class AgeReferenceBlock extends ContentBlock {
  final String ageUnit;
  final List<Map<String, dynamic>> rows;

  AgeReferenceBlock({required this.ageUnit, required this.rows}) 
      : super(type: BlockType.ageReference);

  factory AgeReferenceBlock.fromJson(Map<String, dynamic> json) {
    return AgeReferenceBlock(
      ageUnit: json['age_unit'] ?? '',
      rows: (json['rows'] as List?)?.map((e) => e as Map<String, dynamic>).toList() ?? [],
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'age_reference',
    'age_unit': ageUnit,
    'rows': rows,
  };
}

class AlgorithmBlock extends ContentBlock {
  final String title;
  final List<String> steps;

  AlgorithmBlock({required this.title, required this.steps}) 
      : super(type: BlockType.algorithm);

  factory AlgorithmBlock.fromJson(Map<String, dynamic> json) {
    return AlgorithmBlock(
      title: json['title'] ?? '',
      steps: (json['steps'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'algorithm',
    'title': title,
    'steps': steps,
  };
}

class KeyValueItem {
  final String key;
  final String value;

  const KeyValueItem({required this.key, required this.value});

  factory KeyValueItem.fromJson(Map<String, dynamic> json) => KeyValueItem(
        key: json['key']?.toString() ?? '',
        value: json['value']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {'key': key, 'value': value};
}

class KeyValueBlock extends ContentBlock {
  final String? title;
  final List<KeyValueItem> items;

  KeyValueBlock({this.title, required this.items})
      : super(type: BlockType.keyValue);

  factory KeyValueBlock.fromJson(Map<String, dynamic> json) => KeyValueBlock(
        title: json['title'] as String?,
        items: (json['items'] as List?)
                ?.map((e) => KeyValueItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  @override
  Map<String, dynamic> toJson() => {
        'type': 'key_value',
        'title': title,
        'items': items.map((e) => e.toJson()).toList(),
      };
}

class ParagraphBlock extends ContentBlock {
  final String text;

  ParagraphBlock({required this.text}) 
      : super(type: BlockType.paragraph);

  factory ParagraphBlock.fromJson(Map<String, dynamic> json) {
    return ParagraphBlock(
      text: json['text'] ?? '',
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'paragraph',
    'text': text,
  };
}
