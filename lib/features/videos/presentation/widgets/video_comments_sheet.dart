import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/failure_l10n.dart';
import '../../../../core/network/api_failure.dart';
import '../../../../core/routing/auth_gate.dart';
import '../../../../generated/l10n/app_localizations.dart';
import '../../../ugc/presentation/ugc_actions.dart';
import '../../data/video_models.dart';
import '../../domain/video_feed_controller.dart';

class VideoCommentsSheet extends ConsumerStatefulWidget {
  const VideoCommentsSheet({super.key, required this.videoId});

  final String videoId;

  @override
  ConsumerState<VideoCommentsSheet> createState() => _VideoCommentsSheetState();
}

class _VideoCommentsSheetState extends ConsumerState<VideoCommentsSheet> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  List<VideoComment> _comments = const [];
  String? _nextUrl;
  Object? _error;
  bool _loading = true;
  bool _loadingMore = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 180) _loadMore();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ref
          .read(videoApiProvider)
          .fetchComments(widget.videoId);
      if (!mounted) return;
      setState(() {
        _comments = page.items;
        _nextUrl = page.nextUrl;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final next = _nextUrl;
    if (next == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await ref
          .read(videoApiProvider)
          .fetchComments(widget.videoId, nextUrl: next);
      if (!mounted) return;
      final known = _comments.map((comment) => comment.id).toSet();
      setState(() {
        _comments = [
          ..._comments,
          ...page.items.where((comment) => known.add(comment.id)),
        ];
        _nextUrl = page.nextUrl;
        _loadingMore = false;
      });
    } on Object {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _submit() async {
    if (!await requireAuthentication(context, ref) || !mounted) return;
    if (!await ensureUgcPolicyAccepted(context, ref) || !mounted) return;
    final text = _textController.text.trim();
    if (text.isEmpty || _sending) return;
    final temporaryId = 'pending-${DateTime.now().microsecondsSinceEpoch}';
    final optimistic = VideoComment(
      id: temporaryId,
      user: VideoCommentUser(
        id: 'me',
        name: AppLocalizations.of(context).videoYou,
      ),
      text: text,
      isOwner: true,
      createdAt: DateTime.now(),
      isPending: true,
    );
    setState(() {
      _sending = true;
      _comments = [optimistic, ..._comments];
      _textController.clear();
    });
    ref
        .read(videoFeedControllerProvider.notifier)
        .changeCommentCount(widget.videoId, 1);
    try {
      final saved = await ref
          .read(videoApiProvider)
          .createComment(widget.videoId, text);
      if (!mounted) return;
      setState(() {
        _comments = [
          for (final comment in _comments)
            if (comment.id == temporaryId) saved else comment,
        ];
        _sending = false;
      });
    } on Object catch (error) {
      ref
          .read(videoFeedControllerProvider.notifier)
          .changeCommentCount(widget.videoId, -1);
      if (!mounted) return;
      setState(() {
        _comments = _comments.where((item) => item.id != temporaryId).toList();
        _sending = false;
        _textController.text = text;
      });
      _showFailure(error);
    }
  }

  Future<void> _onCommentAction(
    VideoComment comment,
    _CommentAction action,
  ) async {
    switch (action) {
      case _CommentAction.report:
        await reportUgcContent(
          context,
          ref,
          targetType: 'video_comment',
          targetId: comment.id,
        );
        break;
      case _CommentAction.block:
        final blocked = await blockUgcUser(
          context,
          ref,
          userId: comment.user.id,
          displayName: comment.user.name,
        );
        if (blocked && mounted) {
          setState(
            () => _comments = _comments
                .where((item) => item.user.id != comment.user.id)
                .toList(growable: false),
          );
        }
        break;
    }
  }

  Future<void> _delete(VideoComment comment) async {
    final index = _comments.indexOf(comment);
    if (index < 0 || comment.isPending) return;
    setState(
      () =>
          _comments = _comments.where((item) => item.id != comment.id).toList(),
    );
    ref
        .read(videoFeedControllerProvider.notifier)
        .changeCommentCount(widget.videoId, -1);
    try {
      await ref
          .read(videoApiProvider)
          .deleteComment(widget.videoId, comment.id);
    } on Object catch (error) {
      ref
          .read(videoFeedControllerProvider.notifier)
          .changeCommentCount(widget.videoId, 1);
      if (!mounted) return;
      final restored = [..._comments]
        ..insert(index.clamp(0, _comments.length), comment);
      setState(() => _comments = restored);
      _showFailure(error);
    }
  }

  void _showFailure(Object error) {
    final l10n = AppLocalizations.of(context);
    final message = error is ApiFailure
        ? error.localize(l10n)
        : l10n.errorUnknown;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .82,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: colors.outlineVariant,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.videoCommentsTitle,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const Divider(height: 1),
            Expanded(child: _body(l10n)),
            const Divider(height: 1),
            Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 8,
                top: 8,
                bottom: 8 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      maxLength: 500,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        hintText: l10n.videoCommentHint,
                        counterText: '',
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.videoCommentSend,
                    onPressed: _sending ? null : _submit,
                    icon: _sending
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(AppLocalizations l10n) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      final message = _error is ApiFailure
          ? (_error! as ApiFailure).localize(l10n)
          : l10n.videoLoadError;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            TextButton(onPressed: _loadInitial, child: Text(l10n.commonRetry)),
          ],
        ),
      );
    }
    if (_comments.isEmpty) {
      return Center(child: Text(l10n.videoCommentsEmpty));
    }
    return ListView.builder(
      controller: _scrollController,
      itemCount: _comments.length + (_loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _comments.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final comment = _comments[index];
        return ListTile(
          leading: CircleAvatar(
            child: Text(
              comment.user.name.isEmpty
                  ? '?'
                  : comment.user.name[0].toUpperCase(),
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  comment.user.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (comment.isPending)
                const SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
            ],
          ),
          subtitle: Text(comment.text),
          trailing: comment.isOwner
              ? IconButton(
                  tooltip: l10n.commonDelete,
                  onPressed: () => _delete(comment),
                  icon: const Icon(Icons.delete_outline, size: 20),
                )
              : comment.user.id.isEmpty
              ? null
              : PopupMenuButton<_CommentAction>(
                  tooltip: l10n.ugcContentActions,
                  onSelected: (action) => _onCommentAction(comment, action),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: _CommentAction.report,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.flag_outlined),
                        title: Text(l10n.ugcReport),
                      ),
                    ),
                    PopupMenuItem(
                      value: _CommentAction.block,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.person_off_outlined),
                        title: Text(l10n.ugcBlockUser),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

enum _CommentAction { report, block }
