import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Drop-in replacement for DropdownButtonFormField<String> used for the long
/// vendor/factory location lists (source/destination pickers on the new
/// order page). Adds live search filtering so users don't have to scroll a
/// long list; keeps the same external contract (value/items/onChanged/
/// validator/labelText/hintText) as the dropdown it replaces, so selecting a
/// location still triggers exactly the same side effects (price
/// recalculation, vehicle matching, etc.) as before.
class SearchableLocationDropdown extends StatefulWidget {
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final FormFieldValidator<String>? validator;
  final String labelText;
  final String? hintText;

  const SearchableLocationDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.validator,
    required this.labelText,
    this.hintText,
  });

  @override
  State<SearchableLocationDropdown> createState() => _SearchableLocationDropdownState();
}

class _SearchableLocationDropdownState extends State<SearchableLocationDropdown> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  final GlobalKey<FormFieldState<String>> _fieldKey = GlobalKey<FormFieldState<String>>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value ?? '');
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant SearchableLocationDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep the visible text in sync if the bound value changes from outside
    // while the field isn't actively focused/being edited.
    if (widget.value != oldWidget.value && !_focusNode.hasFocus) {
      _controller.text = widget.value ?? '';
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus) return;
    final text = _controller.text;
    if (text == (widget.value ?? '')) return;

    // On blur, only commit if the typed text exactly matches an option
    // (case-insensitive). Otherwise revert to the last committed value, so
    // an abandoned search never leaves the field showing text that doesn't
    // match the actual selected value.
    String? exactMatch;
    for (final item in widget.items) {
      if (item.toLowerCase() == text.toLowerCase()) {
        exactMatch = item;
        break;
      }
    }
    if (exactMatch != null) {
      _controller.text = exactMatch;
      _commit(exactMatch);
    } else {
      _controller.text = widget.value ?? '';
    }
  }

  void _commit(String? selection) {
    _fieldKey.currentState?.didChange(selection);
    widget.onChanged(selection);
  }

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      key: _fieldKey,
      initialValue: widget.value,
      validator: widget.validator,
      builder: (field) {
        // RawAutocomplete (not the higher-level Autocomplete) because it's
        // the one that accepts externally-owned textEditingController /
        // focusNode, which we need for the blur-revert logic below.
        return RawAutocomplete<String>(
          textEditingController: _controller,
          focusNode: _focusNode,
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) return widget.items;
            final query = textEditingValue.text.toLowerCase();
            return widget.items.where((item) => item.toLowerCase().contains(query));
          },
          onSelected: (String selection) {
            _controller.text = selection;
            _commit(selection);
          },
          fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
            return TextFormField(
              controller: textController,
              focusNode: focusNode,
              decoration: InputDecoration(
                labelText: widget.labelText,
                hintText: widget.hintText ?? 'Type to search',
                prefixIcon: const Icon(Icons.location_on),
                suffixIcon: const Icon(Icons.search, size: 20),
                errorText: field.errorText,
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                color: AppTheme.darkCard,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.darkBorder, width: 1),
                  ),
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: options.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Text(
                            'No matching location',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (context, index) {
                            final option = options.elementAt(index);
                            return InkWell(
                              onTap: () => onSelected(option),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Text(
                                  option,
                                  style: const TextStyle(color: AppTheme.textPrimary),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
