import 'dart:io';

void main() {
  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    print('Error: lib/ directory not found');
    exit(1);
  }

  print('📁 src/:');
  printDirectory(libDir, '');
}

void printDirectory(Directory dir, String indent) {
  final entities = dir.listSync()..sort((a, b) => a.path.compareTo(b.path));

  // Filter out generated files and dotfiles
  final filtered = entities.where((e) {
    final name = e.path.split('/').last;
    return !name.startsWith('.') && !name.endsWith('.g.dart') && !name.endsWith('file-tile.json');
  }).toList();

  for (int i = 0; i < filtered.length; i++) {
    final entity = filtered[i];
    final name = entity.path.split('/').last;
    final isLast = i == filtered.length - 1;

    final connector = isLast ? '└── ' : '├── ';
    final nextIndent = indent + (isLast ? '    ' : '│   ');

    if (entity is Directory) {
      print('$indent$connector📁 $name/');
      printDirectory(entity, nextIndent);
    } else {
      print('$indent$connector📄 $name');
    }
  }
}
