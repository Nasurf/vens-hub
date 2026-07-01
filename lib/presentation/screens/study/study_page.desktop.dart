import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:vens_hub/presentation/blocs/study/study_bloc.dart';
import 'package:vens_hub/presentation/screens/study/pdf_view_page.dart';
import 'package:vens_hub/data/models/textbook_model.dart';
import 'package:vens_hub/core/services/storage/r2_upload_service.dart';
import 'package:vens_hub/core/config/app_config.dart';
import 'package:vens_hub/presentation/widgets/common/app_notification.dart';

class DesktopStudyPage extends StatefulWidget {
  const DesktopStudyPage({super.key});

  @override
  State<DesktopStudyPage> createState() => _DesktopStudyPageState();
}

class _DesktopStudyPageState extends State<DesktopStudyPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  bool _isUploading = false;
  bool _progressOpen = false;
  OverlayEntry? _progressOverlayEntry;
  Timer? _progressSafetyTimer;
  // Cache for uploads
  List<Map<String, dynamic>> _cachedUploads = [];
  bool _uploadsLoading = false;
  String? _uploadsError;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
    _fetchUploads();
    _searchFocusNode.addListener(_handleSearchFocusChange);
  }

  @override
  void dispose() {
    _searchFocusNode.removeListener(_handleSearchFocusChange);
    _animationController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _handleSearchFocusChange() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _fetchUploads({bool force = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (_cachedUploads.isNotEmpty && !force) return;
    if (!mounted) return;
    setState(() {
      _uploadsLoading = true;
      _uploadsError = null;
    });
    try {
      final snap =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('uploads')
              .orderBy('created_at', descending: true)
              .limit(100)
              .get();
      if (!mounted) return;
      setState(() {
        _cachedUploads = snap.docs.map((d) => d.data()).toList(growable: false);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploadsError = e.toString();
      });
    } finally {
      if (mounted) setState(() => _uploadsLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<StudyBloc, StudyState>(
      builder: (context, state) {
        if (state is StudyLoaded &&
            _searchController.text != state.searchQuery) {
          _searchController.text = state.searchQuery;
        }

        return Scaffold(
          backgroundColor: theme.colorScheme.surface,
          body: Column(
            children: [
              _buildHeader(context, state),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: _buildMainContent(context, state)),
                    Container(
                      width: 1,
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.2,
                      ),
                    ),
                    Expanded(flex: 3, child: _buildUploadsPanel(context)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, StudyState state) {
    final theme = Theme.of(context);
    final isSearching = state is StudyLoaded && state.isSearching;

    return Container(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.05),
            theme.colorScheme.surface,
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Study Materials',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Access your textbooks and uploaded documents',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(width: 400, child: _buildSearchBar(context, state)),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, StudyState state) {
    final theme = Theme.of(context);
    final bloc = context.read<StudyBloc>();
    final isSearching = state is StudyLoaded && state.isSearching;
    final hasQuery = _searchController.text.isNotEmpty;
    final isActive = isSearching || _searchFocusNode.hasFocus || hasQuery;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 48,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color:
              isActive
                  ? theme.colorScheme.primary.withValues(alpha: 0.45)
                  : theme.colorScheme.outline.withValues(alpha: 0.15),
        ),
        gradient:
            isActive
                ? LinearGradient(
                  colors: [
                    theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.45,
                    ),
                    theme.colorScheme.surface.withValues(alpha: 0.9),
                  ],
                )
                : null,
        color:
            isActive
                ? null
                : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.25,
                ),
        boxShadow:
            isActive
                ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
                : null,
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48,
            height: double.infinity,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(
                alpha: isActive ? 0.18 : 0.08,
              ),
            ),
            child: Icon(
              Icons.search_rounded,
              color: theme.colorScheme.onPrimaryContainer.withValues(
                alpha: 0.85,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: 'Search by title, author, or subject...',
                hintStyle: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              cursorColor: theme.colorScheme.primary,
              style: TextStyle(color: theme.colorScheme.onSurface),
              onChanged: (value) => bloc.add(SearchQueryUpdated(value)),
              onTap: () {
                if (!isSearching) bloc.add(SearchToggled());
              },
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder:
                (child, anim) => FadeTransition(
                  opacity: anim,
                  child: ScaleTransition(scale: anim, child: child),
                ),
            child:
                isActive
                    ? Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: IconButton(
                        key: const ValueKey('clear'),
                        splashRadius: 20,
                        icon: Icon(
                          Icons.close_rounded,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.7,
                          ),
                        ),
                        onPressed: () {
                          _searchController.clear();
                          bloc.add(const SearchQueryUpdated(''));
                          if (isSearching) bloc.add(SearchToggled());
                          _searchFocusNode.unfocus();
                        },
                      ),
                    )
                    : const SizedBox(width: 4),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, StudyState state) {
    if (state is StudyLoading || state is StudyInitial) {
      return FadeTransition(
        opacity: _fadeAnimation,
        child: _buildLoadingState(Theme.of(context)),
      );
    } else if (state is StudyError) {
      return FadeTransition(
        opacity: _fadeAnimation,
        child: _buildError(Theme.of(context), context, state.message),
      );
    } else if (state is StudyLoaded) {
      if (state.filteredTextbooks.isEmpty) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: _buildEmptyState(Theme.of(context), context, state),
        );
      }
      return _buildGridList(context, state.filteredTextbooks);
    }
    return const SizedBox.shrink();
  }

  Widget _buildGridList(BuildContext context, List<TextBookModel> textbooks) {
    return GridView.builder(
      padding: const EdgeInsets.all(32),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 400,
        mainAxisSpacing: 20,
        crossAxisSpacing: 20,
        childAspectRatio: 2.5,
      ),
      itemCount: textbooks.length,
      itemBuilder: (context, index) {
        return _buildTextbookCard(context, textbooks[index]);
      },
    );
  }

  Widget _buildTextbookCard(BuildContext context, TextBookModel book) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) =>
                        PdfViewScreen(pdfPath: book.url, pdfTitle: book.name),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          hoverColor: theme.colorScheme.primary.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.picture_as_pdf_rounded,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        book.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'PDF Document',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Ready to read',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            'Loading your study materials...',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildError(ThemeData theme, BuildContext context, String error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 64,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Oops! Something went wrong',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              context.read<StudyBloc>().add(
                const LoadStudyMaterials("elect/Data Communication"),
              );
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    ThemeData theme,
    BuildContext context,
    StudyLoaded state,
  ) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 64,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            state.searchQuery.isEmpty
                ? 'No study materials yet'
                : 'No results found',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            state.searchQuery.isEmpty
                ? 'Materials will appear here once available'
                : 'Try adjusting your search terms',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadsPanel(BuildContext context) {
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;

    return Container(
      color: theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
            child: Row(
              children: [
                Text(
                  'Your Uploads',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _isUploading ? null : () => _handleUpload(context),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon:
                      _isUploading
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : const Icon(Icons.upload_file_rounded, size: 20),
                  label: Text(_isUploading ? 'Uploading...' : 'Upload PDF'),
                ),
              ],
            ),
          ),
          Expanded(
            child:
                user == null
                    ? const Center(child: Text('Sign in to see your uploads'))
                    : _uploadsLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _uploadsError != null
                    ? Center(child: Text('Error: $_uploadsError'))
                    : _cachedUploads.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.cloud_upload_outlined,
                            size: 48,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.2,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No uploads yet',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Upload PDFs to access them anywhere',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.all(24),
                      itemCount: _cachedUploads.length,
                      itemBuilder: (context, index) {
                        final doc = _cachedUploads[index];
                        final name = doc['name'] as String? ?? 'Untitled';
                        final path = doc['path'] as String? ?? '';
                        final url =
                            (doc['url'] as String?) ??
                            (path.isNotEmpty ? _generateR2Url(path) : '');
                        final createdAt = doc['created_at'] as Timestamp?;
                        final formattedDate =
                            createdAt != null
                                ? DateFormat(
                                  'MMM d, yyyy',
                                ).format(createdAt.toDate())
                                : 'Unknown date';

                        return Material(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => PdfViewScreen(
                                        pdfPath: doc['url'],
                                        pdfTitle: name,
                                      ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.picture_as_pdf_rounded,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.bodyLarge?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.access_time_rounded,
                                              size: 14,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withValues(alpha: 0.6),
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                formattedDate,
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.bodySmall?.copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurface
                                                      .withValues(alpha: 0.6),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    icon: Icon(
                                      Icons.more_vert_rounded,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.5),
                                    ),
                                    itemBuilder:
                                        (context) => [
                                          const PopupMenuItem(
                                            value: 'open',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.open_in_new,
                                                  size: 18,
                                                ),
                                                SizedBox(width: 12),
                                                Text('Open'),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'share',
                                            child: Row(
                                              children: [
                                                Icon(Icons.share, size: 18),
                                                SizedBox(width: 12),
                                                Text('Share'),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.delete_outline,
                                                  size: 18,
                                                ),
                                                SizedBox(width: 12),
                                                Text('Delete'),
                                              ],
                                            ),
                                          ),
                                        ],
                                    onSelected: (value) {
                                      if (value == 'open') {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (context) => PdfViewScreen(
                                                  pdfPath: doc['url'],
                                                  pdfTitle: name,
                                                ),
                                          ),
                                        );
                                      } else if (value == 'share') {
                                        _shareDocument(context, doc);
                                      } else if (value == 'delete') {
                                        _showDeleteConfirmation(
                                          context,
                                          doc,
                                          theme,
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  void _showSnack(BuildContext context, String msg) {
    AppNotifier.info(context: context, message: msg);
  }

  String _generateR2Url(String objectPath) {
    final encodedPath = objectPath
        .split('/')
        .map(Uri.encodeComponent)
        .join('/');
    return "${AppConfig.r2PublicDomain}/$encodedPath";
  }

  void _showProgressDialogWith(
    OverlayState overlay,
    ThemeData theme,
    String message,
  ) {
    if (_progressOpen) return;

    _progressOverlayEntry = OverlayEntry(
      builder:
          (context) => Center(
            child: Material(
              color: Colors.black54,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: theme.colorScheme.primary),
                    const SizedBox(height: 16),
                    Text(message, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
          ),
    );

    overlay.insert(_progressOverlayEntry!);
    _progressOpen = true;

    // Safety timer to close the dialog if something goes wrong
    _progressSafetyTimer = Timer(const Duration(minutes: 2), () {
      _closeProgressDialog();
      if (mounted) {
        AppNotifier.error(
          context: context,
          message: 'Upload timed out. Please try again.',
        );
      }
    });
  }

  void _closeProgressDialog() {
    _progressSafetyTimer?.cancel();
    _progressSafetyTimer = null;
    _progressOverlayEntry?.remove();
    _progressOverlayEntry = null;
    _progressOpen = false;
  }

  String _sanitizeFilename(String filename) {
    // Replace characters that are problematic in file paths or URLs
    return filename.replaceAll(RegExp(r'[^\w\s\.\-]'), '_').trim();
  }

  void _showDeleteConfirmation(
    BuildContext context,
    Map<String, dynamic> document,
    ThemeData theme,
  ) {
    final name = document['name'] as String? ?? 'this document';
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirm Delete'),
            content: Text('Are you sure you want to delete "$name"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _deleteDocument(context, document);
                },
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteDocument(
    BuildContext context,
    Map<String, dynamic> document,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Find and delete from Firestore
      final uploadsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('uploads');

      final query =
          await uploadsRef
              .where('path', isEqualTo: document['path'])
              .limit(1)
              .get();

      if (query.docs.isNotEmpty) {
        await query.docs.first.reference.delete();
        if (!context.mounted) return;
        AppNotifier.success(context: context, message: 'Document deleted');
        await _fetchUploads(force: true);
      }
    } catch (e) {
      if (!context.mounted) return;
      AppNotifier.error(context: context, message: 'Failed to delete: $e');
    }
  }

  void _shareDocument(BuildContext context, Map<String, dynamic> document) {
    final url = document['url'] as String? ?? '';

    if (url.isNotEmpty) {
      // For now, just copy to clipboard - you can integrate with share_plus package
      _showSnack(context, 'Share link copied: $url');
    } else {
      _showSnack(context, 'Unable to share document');
    }
  }

  Future<void> _handleUpload(BuildContext context) async {
    // Capture UI dependencies before any async gap
    final overlay = Overlay.of(context, rootOverlay: true);
    final theme = Theme.of(context);

    try {
      final pick = await FilePicker.platform.pickFiles(
        withData: true,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (pick == null || pick.files.isEmpty) return;
      if (!context.mounted) return;

      final file = pick.files.first;
      final fileBytes = file.bytes;
      if (fileBytes == null) {
        AppNotifier.error(context: context, message: 'Unable to read file');
        return;
      }

      // Enforce size < 30 MB
      if (fileBytes.length > 30 * 1024 * 1024) {
        AppNotifier.warning(
          context: context,
          message: 'File too large. Maximum size is 30MB',
        );
        return;
      }

      // Quick magic-bytes validation for PDFs: %PDF-
      if (fileBytes.length < 5 ||
          fileBytes[0] != 0x25 || // %
          fileBytes[1] != 0x50 || // P
          fileBytes[2] != 0x44 || // D
          fileBytes[3] != 0x46 || // F
          fileBytes[4] != 0x2D) {
        // -
        AppNotifier.warning(
          context: context,
          message: 'Only PDF files are allowed',
        );
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        AppNotifier.warning(
          context: context,
          message: 'Please sign in to upload',
        );
        return;
      }

      final now = DateTime.now().toUtc();
      final ts = DateFormat("yyyy-MM-dd'T'HH-mm-ss.SSS'Z'").format(now);
      final cleanName = _sanitizeFilename(file.name);
      final objectKey = 'users/${user.uid}/notes/${ts}_$cleanName';

      final meta = <String, String>{
        'category': 'notes',
        'intent': 'study_material',
        'orig_filename': cleanName,
        'ts': (now.millisecondsSinceEpoch ~/ 1000).toString(),
        'uid': user.uid,
      };

      if (!mounted) return;
      setState(() {
        _isUploading = true;
      });

      _showProgressDialogWith(overlay, theme, 'Uploading $cleanName…');

      // 1) Upload to R2
      final url = await R2UploadService.uploadPdf(
        objectKey: objectKey,
        fileBytes: fileBytes,
        originalFilename: cleanName,
        metadata: meta,
      );

      // 2) Log metadata to Firestore
      await _addToFirestoreWithRetry(
        user.uid,
        url,
        cleanName,
        objectKey,
        now,
        sizeBytes: fileBytes.length,
      );

      if (!context.mounted) return;
      AppNotifier.success(context: context, message: 'Upload complete ✅');
      await _fetchUploads(force: true);
    } catch (e) {
      if (!context.mounted) return;
      AppNotifier.error(
        context: context,
        message: 'Upload failed: ${e.toString()}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
      _closeProgressDialog();
    }
  }

  Future<void> _addToFirestoreWithRetry(
    String uid,
    String url,
    String fileName,
    String objectKey,
    DateTime now, {
    required int sizeBytes,
  }) async {
    int attempts = 0;
    const maxAttempts = 3;

    while (attempts < maxAttempts) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('uploads')
            .add({
              'path': objectKey,
              'url': url, // ready-to-use Worker URL
              'name': fileName,
              'size_bytes': sizeBytes,
              'content_type': 'application/pdf',
              'created_at': FieldValue.serverTimestamp(),
              'meta': {
                'category': 'notes',
                'intent': 'study_material',
                'orig_filename': fileName,
                'ts': now.millisecondsSinceEpoch ~/ 1000,
              },
            });
        return;
      } catch (e) {
        attempts++;
        if (attempts >= maxAttempts) rethrow;
        await Future.delayed(Duration(seconds: 1 << attempts));
      }
    }
  }
}
