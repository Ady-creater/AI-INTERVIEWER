import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class FilePickerWidget extends StatefulWidget {
  final Function(PlatformFile?) onFileSelected;
  final Function(PlatformFile?)? onCancel;
  const FilePickerWidget({super.key, required this.onFileSelected, this.onCancel});

  @override
  State<FilePickerWidget> createState() => _FilePickerState();
}

class _FilePickerState extends State<FilePickerWidget> {
  PlatformFile? _selectedFile;
  bool _isPicking = false;

  Future<void> _pickFile() async {
    if (_isPicking) return;
    setState(() {
      _isPicking = true;
    });

    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx'],
        allowMultiple: false,
        withData: kIsWeb
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFile = result.files.first;
        });
        widget.onFileSelected(_selectedFile);
      }
    } catch (e) {
      debugPrint("Error picking file: $e");
    } finally {
      setState(() {
        _isPicking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_selectedFile != null) ...[
          Card(
            margin: EdgeInsets.symmetric(horizontal: 16),
            child: ListTile(
              leading: Icon(Icons.insert_drive_file, color: Colors.blue),
              title: Text(
                _selectedFile!.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${(_selectedFile!.size / 1024).toStringAsFixed(2)} KB | Type: ${_selectedFile!.extension ?? 'Unknown'}',
              ),
              trailing: IconButton(
                onPressed: () {
                  widget.onCancel!(_selectedFile);
                  setState(() {
                    _selectedFile = null;
                  });
                },
                icon: Icon(Icons.clear, color: Colors.red),
              ),
            ),
          ),
        ] else ...[
          ElevatedButton.icon(
            onPressed: _isPicking ? null : _pickFile,
            icon: _isPicking
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon((Icons.upload_file)),
            label: Text(_isPicking ? 'Opening Picker...' : 'Select File'),
          ),
          const SizedBox(height: 16),
          const Text(
            "No file selected",
            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
          ),
        ],
      ],
    );
  }
}
