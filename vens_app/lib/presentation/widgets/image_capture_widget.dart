import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:vens_hub/presentation/widgets/common/app_notification.dart';

class ImageCaptureWidget extends StatefulWidget {
  final Function(List<File>) onImagesSelected;
  final Function(List<Uint8List>)? onImageBytesSelected; // For web
  final List<File> existingImages;

  const ImageCaptureWidget({
    super.key,
    required this.onImagesSelected,
    this.onImageBytesSelected,
    this.existingImages = const [],
  });

  @override
  State<ImageCaptureWidget> createState() => _ImageCaptureWidgetState();
}

class _ImageCaptureWidgetState extends State<ImageCaptureWidget> {
  final ImagePicker _picker = ImagePicker();
  List<File> _selectedImages = [];
  final List<Uint8List> _selectedImageBytes = []; // For web

  @override
  void initState() {
    super.initState();
    _selectedImages = List.from(widget.existingImages);
  }

  Future<void> _requestCameraPermission() async {
    if (kIsWeb) return; // Web handles permissions differently

    final status = await Permission.camera.status;
    if (!status.isGranted) {
      final result = await Permission.camera.request();
      if (!result.isGranted && mounted) {
        AppNotifier.warning(
          context: context,
          message: 'Camera permission is required to take photos',
        );
      }
    }
  }

  Future<void> _requestGalleryPermission() async {
    if (kIsWeb) return; // Web handles permissions differently

    // For iOS 14+ and Android 13+, we need photo library permission
    if (Platform.isIOS) {
      final status = await Permission.photos.status;
      if (!status.isGranted) {
        final result = await Permission.photos.request();
        if (!result.isGranted && mounted) {
          AppNotifier.warning(
            context: context,
            message: 'Photo library permission is required to select images',
          );
        }
      }
    }
  }

  Future<void> _captureImage() async {
    await _requestCameraPermission();

    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85, // Compress to reduce size
      );

      if (photo != null) {
        if (kIsWeb) {
          final bytes = await photo.readAsBytes();
          setState(() {
            _selectedImageBytes.add(bytes);
          });
          widget.onImageBytesSelected?.call(_selectedImageBytes);
        } else {
          setState(() {
            _selectedImages.add(File(photo.path));
          });
          widget.onImagesSelected(_selectedImages);
        }
      }
    } catch (e) {
      if (mounted) {
        AppNotifier.error(
          context: context,
          message: 'Failed to capture image: $e',
        );
      }
    }
  }

  Future<void> _pickImage() async {
    if (kIsWeb) {
      // Use file_picker for web
      try {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
          withData: true, // Important for web
        );

        if (result != null && result.files.isNotEmpty) {
          final file = result.files.first;
          if (file.bytes != null) {
            setState(() {
              _selectedImageBytes.add(file.bytes!);
            });
            widget.onImageBytesSelected?.call(_selectedImageBytes);
          }
        }
      } catch (e) {
        if (mounted) {
          AppNotifier.error(
            context: context,
            message: 'Failed to pick image: $e',
          );
        }
      }
    } else {
      // Use image_picker for mobile
      await _requestGalleryPermission();

      try {
        final XFile? image = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
        );

        if (image != null) {
          setState(() {
            _selectedImages.add(File(image.path));
          });
          widget.onImagesSelected(_selectedImages);
        }
      } catch (e) {
        if (mounted) {
          AppNotifier.error(
            context: context,
            message: 'Failed to pick image: $e',
          );
        }
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      if (kIsWeb) {
        _selectedImageBytes.removeAt(index);
        widget.onImageBytesSelected?.call(_selectedImageBytes);
      } else {
        _selectedImages.removeAt(index);
        widget.onImagesSelected(_selectedImages);
      }
    });
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(
                    Icons.camera_alt,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: const Text('Take Photo'),
                  onTap: () {
                    Navigator.pop(context);
                    _captureImage();
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.photo_library,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: const Text('Choose from Gallery'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.cancel, color: Colors.red),
                  title: const Text('Cancel'),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImages =
        kIsWeb ? _selectedImageBytes.isNotEmpty : _selectedImages.isNotEmpty;
    final imageCount =
        kIsWeb ? _selectedImageBytes.length : _selectedImages.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image preview grid
        if (hasImages) ...[
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: imageCount,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child:
                            kIsWeb
                                ? Image.memory(
                                  _selectedImageBytes[index],
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                )
                                : Image.file(
                                  _selectedImages[index],
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removeImage(index),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Add image button
        OutlinedButton.icon(
          onPressed: _showImageOptions,
          icon: const Icon(Icons.add_photo_alternate),
          label: Text(hasImages ? 'Add Another Image' : 'Add Image'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }
}
