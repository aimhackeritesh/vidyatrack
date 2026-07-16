import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';

/// Pick a file and upload it to POST /uploads. Returns {url, type, size} or
/// null if the user cancelled or the upload failed (a snackbar is shown on failure).
Future<Map<String, dynamic>?> pickAndUploadFile(BuildContext context, WidgetRef ref) async {
  final picked = await FilePicker.platform.pickFiles(
    withData: true,
    type: FileType.custom,
    allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
  );
  if (picked == null || picked.files.isEmpty) return null;
  final file = picked.files.first;
  if (file.bytes == null) return null;

  try {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(file.bytes!, filename: file.name),
    });
    final res = await ref.read(dioProvider).post('/uploads', data: formData);
    return res.data as Map<String, dynamic>;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload failed — try again')));
    }
    return null;
  }
}

/// Compact "Attach file" row: shows a button, then the picked filename + a
/// remove (x) once one is picked. [onChanged] receives the uploaded file's URL (or null).
class FileUploadField extends ConsumerStatefulWidget {
  final String? initialUrl;
  final ValueChanged<String?> onChanged;
  const FileUploadField({super.key, this.initialUrl, required this.onChanged});

  @override
  ConsumerState<FileUploadField> createState() => _FileUploadFieldState();
}

class _FileUploadFieldState extends ConsumerState<FileUploadField> {
  String? _url;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _url = widget.initialUrl;
  }

  Future<void> _pick() async {
    setState(() => _uploading = true);
    final result = await pickAndUploadFile(context, ref);
    if (result != null) {
      setState(() => _url = result['url'] as String);
      widget.onChanged(_url);
    }
    if (mounted) setState(() => _uploading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_uploading) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator());
    }
    if (_url != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: AppColors.successLight, borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            const Icon(Icons.attach_file_rounded, size: 18, color: AppColors.success),
            const SizedBox(width: 8),
            Expanded(child: Text(_url!.split('/').last, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.success))),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: () {
                setState(() => _url = null);
                widget.onChanged(null);
              },
            ),
          ],
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: _pick,
      icon: const Icon(Icons.attach_file_rounded, size: 18),
      label: const Text('Attach file (PDF/image)'),
    );
  }
}
