import 'package:flutter/material.dart';

import '../../../../core/ui/theme/app_colors.dart';
import '../../../../generated/l10n/app_localizations.dart';

const maxShashlikQuantity = 999999;

/// One inline integer editor. The caller owns the last valid draft; incomplete
/// typing never becomes a cart mutation or a fabricated zero total.
class ShashlikQuantityPicker extends StatefulWidget {
  const ShashlikQuantityPicker({
    super.key,
    required this.quantity,
    required this.quantityLabel,
    required this.onChanged,
    required this.onScrollingChanged,
    this.onValidityChanged,
    this.unitLabel,
    this.enabled = true,
    this.horizontal = true,
  });
  final int quantity;
  final String quantityLabel;
  final String? unitLabel;
  final ValueChanged<int> onChanged;
  final ValueChanged<bool> onScrollingChanged;
  final ValueChanged<bool>? onValidityChanged;
  final bool enabled, horizontal;
  @override
  State<ShashlikQuantityPicker> createState() => _ShashlikQuantityPickerState();
}

class _ShashlikQuantityPickerState extends State<ShashlikQuantityPicker> {
  late final TextEditingController _text;
  final _focus = FocusNode();
  bool _valid = true;
  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: '${widget.quantity}');
  }

  @override
  void didUpdateWidget(covariant ShashlikQuantityPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.quantity != widget.quantity &&
        _text.text != '${widget.quantity}') {
      _text.value = TextEditingValue(
        text: '${widget.quantity}',
        selection: TextSelection.collapsed(offset: '${widget.quantity}'.length),
      );
      _valid = true;
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _change(String raw) {
    final parsed = int.tryParse(raw);
    final valid =
        RegExp(r'^[0-9]{1,6}$').hasMatch(raw) &&
        parsed != null &&
        parsed >= 1 &&
        parsed <= maxShashlikQuantity;
    setState(() => _valid = valid);
    widget.onValidityChanged?.call(valid);
    if (valid) widget.onChanged(parsed);
  }

  void _step(int value) {
    if (!widget.enabled || value < 1 || value > maxShashlikQuantity) return;
    _text.text = '$value';
    _change('$value');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconButton.outlined(
              key: const ValueKey('shashlik-selector-minus'),
              tooltip: l10n.cartDecreaseQuantity,
              onPressed: widget.enabled && widget.quantity > 1
                  ? () => _step(widget.quantity - 1)
                  : null,
              style: IconButton.styleFrom(minimumSize: const Size.square(48)),
              icon: const Icon(Icons.remove),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                key: const ValueKey('shashlik-quantity-input'),
                controller: _text,
                focusNode: _focus,
                enabled: widget.enabled,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.lightTextPrimary,
                ),
                onTap: () => _text.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: _text.text.length,
                ),
                onChanged: _change,
                onSubmitted: (_) {
                  if (_valid) _focus.unfocus();
                },
                decoration: InputDecoration(
                  labelText: l10n.shashlikQuantity,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              key: const ValueKey('shashlik-selector-plus'),
              tooltip: l10n.cartIncreaseQuantity,
              onPressed: widget.enabled && widget.quantity < maxShashlikQuantity
                  ? () => _step(widget.quantity + 1)
                  : null,
              style: IconButton.styleFrom(
                minimumSize: const Size.square(48),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          widget.unitLabel ?? widget.quantityLabel,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.lightTextSecondary),
        ),
        if (!_valid)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              l10n.shashlikQuantityInvalid,
              key: const ValueKey('shashlik-quantity-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }
}
