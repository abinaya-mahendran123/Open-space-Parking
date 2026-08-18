import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class DocumentUploadTile extends StatelessWidget {
  const DocumentUploadTile({
    super.key,
    required this.label,
    required this.filePath,
    required this.onFilePicked,
  });

  final String label;
  final String? filePath;
  final ValueChanged<String> onFilePicked;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );

    if (result != null && result.files.single.path != null) {
      onFilePicked(result.files.single.path!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileName = filePath?.split(RegExp(r'[\\/]')).last;

    return Card(
      child: ListTile(
        leading: Icon(
          filePath != null ? Icons.check_circle : Icons.upload_file,
          color: filePath != null ? Colors.green : null,
        ),
        title: Text(label),
        subtitle: Text(fileName ?? 'Tap to upload (PDF, JPG, PNG)'),
        trailing: const Icon(Icons.chevron_right),
        onTap: _pickFile,
      ),
    );
  }
}
