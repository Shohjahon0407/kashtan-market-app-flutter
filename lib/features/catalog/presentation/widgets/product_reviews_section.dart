import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/failure_l10n.dart';
import '../../../../core/network/api_failure.dart';
import '../../../../core/ui/theme/app_buttons.dart';
import '../../../../core/ui/theme/app_dimens.dart';
import '../../../../generated/l10n/app_localizations.dart';
import '../../../auth/domain/auth_controller.dart';
import '../../../ugc/presentation/ugc_actions.dart';
import '../../data/product_models.dart';
import '../../domain/catalog_controller.dart';

class ProductReviewsSection extends ConsumerWidget {
  const ProductReviewsSection({required this.detail, super.key});

  final ProductDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final reviews = ref.watch(productReviewsProvider(detail.product.id));
    final currentUserId = ref.watch(authControllerProvider).user?.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.xxl),
        Text(
          l10n.productReviewsTitle,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        switch (reviews) {
          AsyncData(:final value) when value.isEmpty => Text(
            l10n.productReviewsEmpty,
            style: theme.textTheme.bodySmall,
          ),
          AsyncData(:final value) => Column(
            children: [
              for (final review in value)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              review.userName,
                              style: theme.textTheme.labelLarge,
                            ),
                          ),
                          for (var index = 0; index < 5; index++)
                            Icon(
                              index < review.rating
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              size: 16,
                              color: Colors.amber.shade700,
                            ),
                          if (review.userId.isNotEmpty &&
                              review.userId != currentUserId)
                            PopupMenuButton<_ReviewAction>(
                              tooltip: l10n.ugcContentActions,
                              onSelected: (action) async {
                                switch (action) {
                                  case _ReviewAction.report:
                                    await reportUgcContent(
                                      context,
                                      ref,
                                      targetType: 'product_review',
                                      targetId: review.id,
                                    );
                                  case _ReviewAction.block:
                                    final blocked = await blockUgcUser(
                                      context,
                                      ref,
                                      userId: review.userId,
                                      displayName: review.userName,
                                    );
                                    if (blocked) {
                                      ref.invalidate(
                                        productReviewsProvider(
                                          detail.product.id,
                                        ),
                                      );
                                    }
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: _ReviewAction.report,
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(Icons.flag_outlined),
                                    title: Text(l10n.ugcReport),
                                  ),
                                ),
                                PopupMenuItem(
                                  value: _ReviewAction.block,
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(
                                      Icons.person_off_outlined,
                                    ),
                                    title: Text(l10n.ugcBlockUser),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      if (review.comment.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(review.comment),
                      ],
                    ],
                  ),
                ),
            ],
          ),
          AsyncError(:final error) => Text(
            error is ApiFailure ? error.localize(l10n) : l10n.errorUnknown,
            style: TextStyle(color: theme.colorScheme.error),
          ),
          _ => const Center(child: LinearProgressIndicator()),
        },
        const SizedBox(height: AppSpacing.md),
        if (detail.canReview)
          FilledButton.tonalIcon(
            onPressed: () => _writeReview(context, ref),
            icon: const Icon(Icons.rate_review_outlined),
            label: Text(l10n.productReviewWrite),
          )
        else
          Text(
            detail.hasReviewed
                ? l10n.productReviewAlreadyWritten
                : l10n.productReviewPurchasedOnly,
            style: theme.textTheme.bodySmall,
          ),
      ],
    );
  }

  Future<void> _writeReview(BuildContext context, WidgetRef ref) async {
    if (!await ensureUgcPolicyAccepted(context, ref) || !context.mounted) {
      return;
    }
    final draft = await showDialog<_ReviewDraft>(
      context: context,
      builder: (context) => const _ReviewDialog(),
    );
    if (draft == null || !context.mounted) return;
    final l10n = AppLocalizations.of(context);
    try {
      await ref
          .read(catalogApiProvider)
          .createReview(
            productId: detail.product.id,
            rating: draft.rating,
            comment: draft.comment,
          );
      ref.invalidate(productReviewsProvider(detail.product.id));
      ref.invalidate(productDetailProvider(detail.product.id));
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.productReviewSuccess)));
    } on ApiFailure catch (failure) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.localize(l10n))));
    }
  }
}

enum _ReviewAction { report, block }

class _ReviewDraft {
  const _ReviewDraft(this.rating, this.comment);

  final int rating;
  final String comment;
}

class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog();

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  final _comment = TextEditingController();
  int _rating = 5;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      // Klaviatura ochilganda kontent siqilmasin — o'zi skroll bo'ladi.
      scrollable: true,
      title: Text(l10n.productReviewWrite),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 5 ta odatiy (48dp) IconButton tor ekranda (≤360dp) dialog
          // kengligiga sig'maydi — yulduzlar ixcham (40dp), zarurat bo'lsa
          // FittedBox butun qatorni kichraytiradi.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var value = 1; value <= 5; value++)
                  IconButton(
                    key: ValueKey('product-review-star-$value'),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 40,
                      height: 40,
                    ),
                    onPressed: () => setState(() => _rating = value),
                    icon: Icon(
                      value <= _rating
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: Colors.amber.shade700,
                    ),
                  ),
              ],
            ),
          ),
          TextField(
            controller: _comment,
            maxLength: 2000,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: l10n.productReviewCommentHint,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          style: AppButtons.dialogAction,
          onPressed: () => Navigator.pop(
            context,
            _ReviewDraft(_rating, _comment.text.trim()),
          ),
          child: Text(l10n.productReviewSubmit),
        ),
      ],
    );
  }
}
