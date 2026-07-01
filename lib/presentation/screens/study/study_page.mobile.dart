// SPDX-License-Identifier: MIT
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
import 'package:vens_hub/core/utils/app_logger.dart';

class MobileStudyPage extends StatefulWidget {
  const MobileStudyPage({super.key});

  @override
  State<MobileStudyPage> createState() => _MobileStudyPageState();
}

class _MobileStudyPageState extends State<MobileStudyPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  bool _isUploading = false;
  bool _progressOpen = false;
  OverlayEntry? _progressOverlayEntry;
  Timer? _progressSafetyTimer;
  // Caching for uploads list to reduce Firestore requests
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
      final docs = snap.docs.map((d) => d.data()).toList(growable: false);
      if (!mounted) return;
      setState(() {
        _cachedUploads = docs;
      });
    } catch (e) {
      debugPrint('Failed to load uploads: $e');
      if (!mounted) return;
      setState(() {
        _uploadsError =
            'We couldn\'t load your uploads. Please check your connection and try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _uploadsLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StudyBloc, StudyState>(
      builder: (context, state) {
        if (state is StudyLoaded &&
            _searchController.text != state.searchQuery) {
          _searchController.text = state.searchQuery;
        }

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: Column(
            children: [
              _buildAppBar(context, state),
              Expanded(child: _buildBody(context, state)),
              const Divider(height: 1),
              Expanded(
                child: _buildUploadsPanel(context),
              ), // Firestore-backed list
            ],
          ),
        );
      },
    );
  }

  Widget _buildAppBar(BuildContext context, StudyState state) {
    final theme = Theme.of(context);
    final isSearching = state is StudyLoaded && state.isSearching;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.05),
            theme.colorScheme.surface,
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isSearching) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Study Materials',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              _buildSearchBar(context, state),
            ],
          ),
        ),
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
                hintText: 'Search study materials...',
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

  Widget _buildBody(BuildContext context, StudyState state) {
    if (state is StudyLoading || state is StudyInitial) {
      return FadeTransition(
        opacity: _fadeAnimation,
        child: _buildLoadingState(context),
      );
    } else if (state is StudyError) {
      return FadeTransition(
        opacity: _fadeAnimation,
        child: _buildErrorState(context, state.message),
      );
    } else if (state is StudyLoaded) {
      if (state.filteredTextbooks.isEmpty) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: _buildEmptyState(context, state),
        );
      }
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: state.filteredTextbooks.length,
        itemBuilder:
            (context, i) =>
                _buildTextbookCard(context, state.filteredTextbooks[i], i),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildLoadingState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading your study materials...',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please wait while we fetch your content',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_off_rounded,
                size: 48,
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Unable to load materials',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed:
                  () => context.read<StudyBloc>().add(
                    const LoadStudyMaterials("elect/Data Communication"),
                  ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, StudyLoaded state) {
    final theme = Theme.of(context);
    final hasSearchQuery = state.searchQuery.isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasSearchQuery
                    ? Icons.search_off_rounded
                    : Icons.library_books_outlined,
                size: 48,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              hasSearchQuery ? 'No results found' : 'No study materials yet',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hasSearchQuery
                  ? 'Try adjusting your search terms or browse all materials'
                  : 'Your study materials will appear here once uploaded',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            if (hasSearchQuery) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  context.read<StudyBloc>().add(const SearchQueryUpdated(''));
                },
                icon: const Icon(Icons.clear_all_rounded),
                label: const Text('Clear Search'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTextbookCard(
    BuildContext context,
    TextBookModel book,
    int index,
  ) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        elevation: 0,
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder:
                    (_, a, __) =>
                        PdfViewScreen(pdfPath: book.url, pdfTitle: book.name),
                transitionsBuilder:
                    (_, anim, __, child) =>
                        FadeTransition(opacity: anim, child: child),
                transitionDuration: const Duration(milliseconds: 300),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.picture_as_pdf_rounded,
                    size: 24,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.name,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface,
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

  // ==============================
  // ======== Uploads panel =======
  // ==============================
  Widget _buildUploadsPanel(BuildContext context) {
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;

    return Container(
      height: 260,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.04),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                Text(
                  'Your uploads',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _isUploading ? null : () => _handleUpload(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    foregroundColor: theme.colorScheme.primary,
                    backgroundColor: theme.colorScheme.primary.withValues(
                      alpha: 0.08,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon:
                      _isUploading
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.picture_as_pdf_rounded, size: 18),
                  label: Text(_isUploading ? 'Uploading…' : 'Upload PDF'),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child:
                  user == null
                      ? const Center(child: Text('Sign in to see your uploads'))
                      : RefreshIndicator(
                        onRefresh: () => _fetchUploads(force: true),
                        child:
                            _uploadsLoading
                                ? const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : (_uploadsError != null)
                                ? Center(
                                  child: Text(
                                    'Error loading uploads: $_uploadsError',
                                  ),
                                )
                                : (_cachedUploads.isEmpty)
                                ? Center(
                                  child: Text(
                                    'No uploads yet.\nTap "Upload PDF" to add one.',
                                    textAlign: TextAlign.center,
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                )
                                : ListView.separated(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.only(
                                    bottom: 8,
                                    left: 8,
                                    right: 8,
                                  ),
                                  itemCount: _cachedUploads.length,
                                  separatorBuilder:
                                      (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (_, i) {
                                    final d = _cachedUploads[i];
                                    final path = (d['path'] as String?) ?? '';
                                    final url =
                                        (d['url'] as String?) ??
                                        _generateR2Url(path);
                                    final name =
                                        (d['name'] as String?) ??
                                        (d['meta']?['orig_filename']
                                            as String?) ??
                                        'Document';
                                    final sizeBytes =
                                        (d['size_bytes'] as num?)?.toInt();
                                    final ts = d['created_at'];
                                    final when =
                                        ts is Timestamp ? ts.toDate() : null;
                                    final sizeLabel =
                                        sizeBytes != null
                                            ? _fmtSize(sizeBytes)
                                            : '';

                                    return Material(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest
                                          .withValues(alpha: 0.25),
                                      borderRadius: BorderRadius.circular(12),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        onTap: () {
                                          if (url.isNotEmpty) {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder:
                                                    (_) => PdfViewScreen(
                                                      pdfPath: url,
                                                      pdfTitle: name,
                                                    ),
                                              ),
                                            );
                                          } else {
                                            _showSnack(
                                              context,
                                              'Invalid file path',
                                            );
                                          }
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(14),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  10,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                      .withValues(alpha: 0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Icon(
                                                  Icons.picture_as_pdf_rounded,
                                                  color:
                                                      Theme.of(
                                                        context,
                                                      ).colorScheme.primary,
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
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style: Theme.of(
                                                                  context,
                                                                )
                                                                .textTheme
                                                                .bodyLarge
                                                                ?.copyWith(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Row(
                                                      children: [
                                                        Icon(
                                                          Icons
                                                              .access_time_rounded,
                                                          size: 14,
                                                          color: Theme.of(
                                                                context,
                                                              )
                                                              .colorScheme
                                                              .onSurface
                                                              .withValues(
                                                                alpha: 0.6,
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
                                                        Expanded(
                                                          child: Text(
                                                            when != null
                                                                ? DateFormat.yMMMd()
                                                                    .add_jm()
                                                                    .format(
                                                                      when.toLocal(),
                                                                    )
                                                                : 'Ready',
                                                            style: Theme.of(
                                                                  context,
                                                                )
                                                                .textTheme
                                                                .bodySmall
                                                                ?.copyWith(
                                                                  color: Theme.of(
                                                                        context,
                                                                      )
                                                                      .colorScheme
                                                                      .onSurface
                                                                      .withValues(
                                                                        alpha:
                                                                            0.6,
                                                                      ),
                                                                ),
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 10,
                                                        ),
                                                        Text(
                                                          "•",
                                                          style:
                                                              Theme.of(context)
                                                                  .textTheme
                                                                  .bodySmall,
                                                        ),
                                                        const SizedBox(
                                                          width: 10,
                                                        ),
                                                        Text(
                                                          sizeLabel,
                                                          style: Theme.of(
                                                                context,
                                                              )
                                                              .textTheme
                                                              .bodySmall
                                                              ?.copyWith(
                                                                color: Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .onSurface
                                                                    .withValues(
                                                                      alpha:
                                                                          0.6,
                                                                    ),
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              PopupMenuButton<String>(
                                                icon: const Icon(
                                                  Icons.more_vert,
                                                  size: 20,
                                                ),
                                                onSelected:
                                                    (value) =>
                                                        _handleMenuAction(
                                                          context,
                                                          value,
                                                          d,
                                                        ),
                                                itemBuilder:
                                                    (context) => [
                                                      const PopupMenuItem(
                                                        value: 'delete',
                                                        child: Row(
                                                          children: [
                                                            Icon(
                                                              Icons
                                                                  .delete_outline,
                                                              size: 18,
                                                            ),
                                                            SizedBox(width: 8),
                                                            Text('Delete'),
                                                          ],
                                                        ),
                                                      ),
                                                      const PopupMenuItem(
                                                        value: 'share',
                                                        child: Row(
                                                          children: [
                                                            Icon(
                                                              Icons
                                                                  .share_outlined,
                                                              size: 18,
                                                            ),
                                                            SizedBox(width: 8),
                                                            Text('Share'),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                      ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(
    BuildContext context,
    String action,
    Map<String, dynamic> document,
  ) {
    switch (action) {
      case 'delete':
        _showDeleteConfirmation(context, document);
        break;
      case 'share':
        _shareDocument(context, document);
        break;
    }
  }

  void _showDeleteConfirmation(
    BuildContext pageContext,
    Map<String, dynamic> document,
  ) {
    final name = (document['name'] as String?) ?? 'Document';
    showDialog(
      context: pageContext,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Delete Document'),
            content: Text('Are you sure you want to delete "$name"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _deleteDocument(pageContext, document);
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
    final messenger =
        ScaffoldMessenger.maybeOf(context) ??
        ScaffoldMessenger.maybeOf(this.context);
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

  // ===========================
  // ======== Uploading ========
  // ===========================
  Future<void> _handleUpload(BuildContext context) async {
    // Capture UI dependencies before any async gap
    final messenger =
        ScaffoldMessenger.maybeOf(context) ??
        ScaffoldMessenger.maybeOf(this.context);
    final overlay = Overlay.of(context, rootOverlay: true);
    final theme = Theme.of(context);

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

    // Enforce PDF-only and size < 30 MB
    const maxBytes = 30 * 1024 * 1024; // 30 MB
    if (fileBytes.length > maxBytes) {
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

    // Validate filename
    if (file.name.isEmpty || file.name.length > 200) {
      AppNotifier.warning(
        context: context,
        message: 'Invalid filename: too long or empty',
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
    final ts = now.millisecondsSinceEpoch;
    final cleanName = _sanitizeFilename(file.name);

    // Ensure .pdf extension
    final finalName =
        cleanName.toLowerCase().endsWith('.pdf') ? cleanName : '$cleanName.pdf';
    final objectKey = 'users/${user.uid}/notes/${ts}_$finalName';

    final meta = <String, String>{
      'category': 'notes',
      'intent': 'study_material',
      'orig_filename': finalName,
      'ts': (now.millisecondsSinceEpoch ~/ 1000).toString(),
      'uid': user.uid,
    };

    try {
      _isUploading = true;
      if (mounted) setState(() {});
      _showProgressDialogWith(overlay, theme, 'Uploading $finalName…');

      // 1) Upload to R2 (only Cloudflare write)
      final url = await R2UploadService.uploadPdf(
        objectKey: objectKey,
        fileBytes: fileBytes,
        originalFilename: finalName,
        metadata: meta,
      );

      // 2) Log metadata to Firestore (so future lists never hit R2)
      await _addToFirestoreWithRetry(
        user.uid,
        url,
        finalName,
        objectKey,
        now,
        sizeBytes: fileBytes.length,
      );

      if (!context.mounted) return;
      AppNotifier.success(context: context, message: 'Upload complete ✅');
      // Refresh the uploads list
      await _fetchUploads(force: true);
    } catch (e, st) {
      // Log full error to console for diagnostics and show a concise message.
      AppLogger.e('Upload error', error: e, stackTrace: st);
      final msg = e.toString();
      if (!context.mounted) return;
      AppNotifier.error(
        context: context,
        message:
            'Upload failed: ${msg.length > 140 ? '${msg.substring(0, 140)}...' : msg}',
      );
    } finally {
      _isUploading = false;
      _closeProgressDialog();
      if (mounted) setState(() {});
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

  // ===========================
  // ========= Utils ===========
  // ===========================
  String _sanitizeFilename(String name) {
    return name
        // Allow only safe ASCII filename characters; replace the rest
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();
  }

  void _showProgressDialogWith(
    OverlayState? overlay,
    ThemeData theme,
    String message,
  ) {
    if (_progressOpen) return;
    _progressOpen = true;
    _progressOverlayEntry = OverlayEntry(
      builder: (ctx) {
        return Stack(
          children: [
            ModalBarrier(
              color: Colors.black.withValues(alpha: 0.25),
              dismissible: false,
            ),
            Center(
              child: Material(
                color: theme.colorScheme.surface,
                elevation: 6,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                      const SizedBox(width: 16),
                      Flexible(
                        child: Text(
                          message,
                          style: theme.textTheme.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    overlay?.insert(_progressOverlayEntry!);
    _progressSafetyTimer?.cancel();
    _progressSafetyTimer = Timer(const Duration(seconds: 90), () {
      if (!mounted) return;
      _closeProgressDialog();
    });
  }

  void _closeProgressDialog() {
    _progressOpen = false;
    _progressSafetyTimer?.cancel();
    _progressSafetyTimer = null;
    try {
      _progressOverlayEntry?.remove();
    } catch (_) {}
    _progressOverlayEntry = null;
    // As a fallback, close any stray dialogs on the root navigator
    try {
      Navigator.of(context, rootNavigator: true).maybePop();
    } catch (_) {}
  }

  void _showSnack(BuildContext context, String msg) {
    if (!mounted) return;
    AppNotifier.info(context: context, message: msg);
  }

  String _generateR2Url(String objectPath) {
    final encodedPath = objectPath
        .split('/')
        .map(Uri.encodeComponent)
        .join('/');
    return "${AppConfig.r2PublicDomain}/$encodedPath"; // MUST be Worker domain
  }

  String _fmtSize(int bytes) {
    if (bytes < 1024) return "$bytes B";
    final kb = bytes / 1024;
    if (kb < 1024) return "${kb.toStringAsFixed(1)} KB";
    final mb = kb / 1024;
    if (mb < 1024) return "${mb.toStringAsFixed(1)} MB";
    final gb = mb / 1024;
    return "${gb.toStringAsFixed(2)} GB";
  }
}
