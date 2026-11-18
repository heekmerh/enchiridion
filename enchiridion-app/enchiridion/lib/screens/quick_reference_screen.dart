import 'package:flutter/material.dart';

import '../models/resource_topic.dart';
import 'notebook_screen.dart';
import 'resource_topic_list_screen.dart';

class QuickReferenceScreen extends StatelessWidget {
  const QuickReferenceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OSCE quick reference')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          ListTile(
            leading: const Icon(Icons.bolt_outlined),
            title: const Text('Quick revision'),
            subtitle: Text('${kQuickRevisionTopics.length} parts'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const ResourceTopicListScreen(
                title: 'Quick revision',
                topics: kQuickRevisionTopics,
                dense: true,
              ),
            )),
          ),
          ListTile(
            leading: const Icon(Icons.psychology_alt_outlined),
            title: const Text('Mnemonics'),
            subtitle: Text('${kMnemonicsTopics.length} chapters'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const ResourceTopicListScreen(
                title: 'Mnemonics',
                topics: kMnemonicsTopics,
                dense: true,
              ),
            )),
          ),
          ListTile(
            leading: const Icon(Icons.edit_note),
            title: const Text('Add your notes'),
            subtitle: const Text('Notes and photos, synced to your account'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotebookScreen()),
            ),
          ),
        ],
      ),
    );
  }
}
