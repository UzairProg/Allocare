import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

import '../../../services/ngo_service.dart';
import '../../../services/auth_service.dart';
import '../../needs/application/need_submission_service.dart';

class NgoReportsCenterPage extends ConsumerStatefulWidget {
  const NgoReportsCenterPage({super.key});

  @override
  ConsumerState<NgoReportsCenterPage> createState() =>
      _NgoReportsCenterPageState();
}

class _NgoReportsCenterPageState extends ConsumerState<NgoReportsCenterPage> {
  bool _isUploading = false;
  String _uploadStatus = '';
  String _searchQuery = '';

  String _formatTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 8) {
      return DateFormat('dd MMM yyyy').format(dateTime);
    } else if (difference.inDays >= 1) {
      return '${difference.inDays} ${difference.inDays == 1 ? "day" : "days"} ago';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours} ${difference.inHours == 1 ? "hour" : "hours"} ago';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? "minute" : "minutes"} ago';
    } else {
      return 'Just now';
    }
  }

  String _getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'txt':
        return 'text/plain';
      case 'doc':
      case 'docx':
        return 'application/msword';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _pickAndUploadSingle(String mode) async {
    final allowedExts = mode == 'pdf' ? ['pdf'] : ['png', 'jpg', 'jpeg', 'gif'];
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExts,
      withData: false,
    );

    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;

    final titleController = TextEditingController(
      text: file.name.split('.').first,
    );
    final descController = TextEditingController();

    if (!mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Upload Intelligence Asset',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        mode == 'pdf'
                            ? Icons.picture_as_pdf_rounded
                            : Icons.image_rounded,
                        color: Colors.blue,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          file.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Report Title',
                    labelStyle: GoogleFonts.poppins(fontSize: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Description / Observations',
                    labelStyle: GoogleFonts.poppins(fontSize: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                final title = titleController.text.trim();
                final description = descController.text.trim();
                Navigator.of(dialogContext).pop();

                await _executeUpload(
                  filePath: file.path!,
                  fileName: file.name,
                  title: title.isNotEmpty ? title : file.name,
                  description: description.isNotEmpty
                      ? description
                      : 'NGO Uploaded Intelligence.',
                  extension: file.extension ?? '',
                );
              },
              child: const Text('Upload'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickAndUploadMultiple() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf',
        'png',
        'jpg',
        'jpeg',
        'gif',
        'txt',
        'doc',
        'docx',
      ],
      allowMultiple: true,
      withData: false,
    );

    if (result == null || result.files.isEmpty) return;

    final filesCount = result.files.length;
    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Batch Upload',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Do you want to upload all $filesCount files as intelligence reports?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Confirm Upload'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() {
      _isUploading = true;
      _uploadStatus = 'Batch uploading $filesCount files...';
    });

    try {
      final ngoId = ref.read(effectiveNgoIdProvider) ?? '';
      final currentUserId =
          ref.read(authServiceProvider).currentUser?.uid ?? '';
      final uploadService = ref.read(needSubmissionServiceProvider);

      int uploaded = 0;
      for (final file in result.files) {
        if (file.path == null) continue;

        setState(() {
          _uploadStatus =
              'Uploading [${uploaded + 1}/$filesCount]: ${file.name}...';
        });

        final secureUrl = await uploadService.uploadToCloudinary(
          File(file.path!),
        );

        await FirebaseFirestore.instance.collection('ngo_reports').add({
          'ngoId': ngoId,
          'title': file.name.split('.').first,
          'description': 'Batch upload of multiple intelligence assets.',
          'reportType': file.extension?.toUpperCase() ?? 'FILE',
          'fileUrl': secureUrl,
          'fileType': _getMimeType(file.extension ?? ''),
          'uploadedBy': currentUserId,
          'createdAt': FieldValue.serverTimestamp(),
          'geminiProcessed': false,
          'geminiSummary': '',
        });

        uploaded++;
      }

      _showSuccessSnackBar(
        'Batch upload completed! Successfully uploaded $uploaded files.',
      );
    } catch (e) {
      _showErrorSnackBar('Batch upload failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadStatus = '';
        });
      }
    }
  }

  Future<void> _executeUpload({
    required String filePath,
    required String fileName,
    required String title,
    required String description,
    required String extension,
  }) async {
    setState(() {
      _isUploading = true;
      _uploadStatus = 'Uploading asset to Cloudinary...';
    });

    try {
      final uploadService = ref.read(needSubmissionServiceProvider);
      final secureUrl = await uploadService.uploadToCloudinary(File(filePath));

      setState(() {
        _uploadStatus = 'Saving report metadata...';
      });

      final ngoId = ref.read(effectiveNgoIdProvider) ?? '';
      final currentUserId =
          ref.read(authServiceProvider).currentUser?.uid ?? '';

      await FirebaseFirestore.instance.collection('ngo_reports').add({
        'ngoId': ngoId,
        'title': title,
        'description': description,
        'reportType': extension.toUpperCase(),
        'fileUrl': secureUrl,
        'fileType': _getMimeType(extension),
        'uploadedBy': currentUserId,
        'createdAt': FieldValue.serverTimestamp(),
        'geminiProcessed': false,
        'geminiSummary': '',
      });

      _showSuccessSnackBar('Intelligence report uploaded successfully!');
    } catch (e) {
      _showErrorSnackBar('Upload failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadStatus = '';
        });
      }
    }
  }

  void _showSuccessSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _viewReportAsset(Map<String, dynamic> data) async {
    final url = data['fileUrl']?.toString() ?? '';
    final title = data['title']?.toString() ?? 'Report';
    final fileType = data['fileType']?.toString() ?? '';
    final isImage = fileType.startsWith('image/');

    if (url.isEmpty) {
      _showErrorSnackBar('File URL is not available.');
      return;
    }

    if (isImage) {
      showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return Dialog(
            insetPadding: const EdgeInsets.all(16),
            backgroundColor: Colors.black,
            child: Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        );
                      },
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 24,
                    ),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ),
              ],
            ),
          );
        },
      );
    } else {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showErrorSnackBar('Could not launch file preview URL.');
      }
    }
  }

  Future<void> _deleteReport(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Report?'),
          content: const Text(
            'Are you sure you want to delete this uploaded intelligence report?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('ngo_reports')
          .doc(id)
          .delete();
      _showSuccessSnackBar('Report deleted.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ngoId = ref.watch(effectiveNgoIdProvider) ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'NGO Reports Center',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Upload controls banner
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isUploading) ...[
                  LinearProgressIndicator(
                    backgroundColor: Colors.blue.withValues(alpha: 0.1),
                    color: const Color(0xFF2563EB),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _uploadStatus,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF475569),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  'UPLOAD NEW INTEL ASSET',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE0F2FE),
                          foregroundColor: const Color(0xFF0369A1),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isUploading
                            ? null
                            : () => _pickAndUploadSingle('pdf'),
                        icon: const Icon(
                          Icons.picture_as_pdf_rounded,
                          size: 16,
                        ),
                        label: Text(
                          'Upload PDF',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFECFDF5),
                          foregroundColor: const Color(0xFF047857),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isUploading
                            ? null
                            : () => _pickAndUploadSingle('image'),
                        icon: const Icon(Icons.image_rounded, size: 16),
                        label: Text(
                          'Upload Image',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    foregroundColor: const Color(0xFF334155),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isUploading ? null : _pickAndUploadMultiple,
                  icon: const Icon(Icons.library_add_rounded, size: 16),
                  label: Text(
                    'Batch Upload Multiple Files',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (val) =>
                  setState(() => _searchQuery = val.trim().toLowerCase()),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                hintText: 'Search intelligence uploads...',
                hintStyle: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF94A3B8),
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF64748B),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
            ),
          ),

          // List Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Text(
              'UPLOADED INTEL FEED',
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF64748B),
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Reports Stream List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('ngo_reports')
                  .where('ngoId', isEqualTo: ngoId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                var reports = docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>? ?? {};
                  return {'id': doc.id, ...data};
                }).toList();

                // Apply search filter
                if (_searchQuery.isNotEmpty) {
                  reports = reports.where((r) {
                    final title = r['title']?.toString().toLowerCase() ?? '';
                    final desc =
                        r['description']?.toString().toLowerCase() ?? '';
                    return title.contains(_searchQuery) ||
                        desc.contains(_searchQuery);
                  }).toList();
                }

                // Sort by createdAt descending
                reports.sort((a, b) {
                  final aTs = a['createdAt'] as Timestamp?;
                  final bTs = b['createdAt'] as Timestamp?;
                  if (aTs == null) return 1;
                  if (bTs == null) return -1;
                  return bTs.compareTo(aTs);
                });

                if (reports.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.folder_open_rounded,
                            size: 48,
                            color: const Color(0xFF94A3B8),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No intelligence assets uploaded yet.',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Upload reports, images, or PDFs to feed AlloCare Live Intelligence.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: reports.length,
                  itemBuilder: (context, index) {
                    final report = reports[index];
                    final docId = report['id'] as String;
                    final title =
                        report['title']?.toString() ?? 'Untitled Asset';
                    final description = report['description']?.toString() ?? '';
                    final reportType =
                        report['reportType']?.toString() ?? 'FILE';
                    final fileType = report['fileType']?.toString() ?? '';
                    final isImage = fileType.startsWith('image/');
                    final isPdf =
                        fileType.contains('pdf') ||
                        reportType.toUpperCase() == 'PDF';

                    final cTs = report['createdAt'] as Timestamp?;
                    final timeStr = cTs != null
                        ? _formatTimeAgo(cTs.toDate())
                        : 'Recently';

                    final isProcessed =
                        report['geminiProcessed'] as bool? ?? false;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: InkWell(
                        onTap: () => _viewReportAsset(report),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color:
                                      (isImage
                                              ? Colors.blueAccent
                                              : (isPdf
                                                    ? Colors.red
                                                    : Colors.indigo))
                                          .withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  isImage
                                      ? Icons.image_rounded
                                      : (isPdf
                                            ? Icons.picture_as_pdf_rounded
                                            : Icons.description_rounded),
                                  color: isImage
                                      ? Colors.blueAccent
                                      : (isPdf ? Colors.red : Colors.indigo),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: const Color(0xFF1E293B),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      description.isNotEmpty
                                          ? description
                                          : 'No description provided.',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '$reportType • $timeStr',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: const Color(0xFF94A3B8),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                (isProcessed
                                                        ? Colors.green
                                                        : Colors.amber)
                                                    .withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color:
                                                  (isProcessed
                                                          ? Colors.green
                                                          : Colors.amber)
                                                      .withValues(alpha: 0.3),
                                            ),
                                          ),
                                          child: Text(
                                            isProcessed
                                                ? 'Gemini Processed'
                                                : 'Awaiting Gemini Process',
                                            style: GoogleFonts.poppins(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: isProcessed
                                                  ? Colors.green
                                                  : Colors.amber.shade700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Color(0xFF94A3B8),
                                  size: 20,
                                ),
                                onPressed: () => _deleteReport(docId),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
