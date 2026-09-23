import 'dart:io';

import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../application/order_workspace_controller.dart';
import '../domain/order_models.dart';

class ItemsPage extends StatefulWidget {
  const ItemsPage({super.key, required this.controller});

  final OrderWorkspaceController controller;

  @override
  State<ItemsPage> createState() => _ItemsPageState();
}

class _ItemsPageState extends State<ItemsPage> {
  String _query = '';
  String? _categoryId;
  bool _favouritesOnly = false;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final l = AppLocalizations.of(context);
      final filtered = widget.controller.items.where((item) {
        final query = _query.trim().toLowerCase();
        final matchesQuery =
            query.isEmpty ||
            item.name.toLowerCase().contains(query) ||
            (item.category?.name.toLowerCase().contains(query) ?? false);
        final matchesCategory =
            _categoryId == null || item.category?.id == _categoryId;
        return matchesQuery &&
            matchesCategory &&
            (!_favouritesOnly || item.isFavourite);
      }).toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilledButton.icon(
            key: const ValueKey('add-item'),
            onPressed: widget.controller.saving ? null : () => _openEditor(),
            icon: const Icon(Icons.add_rounded),
            label: Text(l.addItem),
          ),
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, constraints) => Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: constraints.maxWidth >= 700
                      ? constraints.maxWidth * 0.48
                      : constraints.maxWidth,
                  child: TextField(
                    key: const ValueKey('item-search'),
                    decoration: InputDecoration(
                      labelText: l.searchItems,
                      prefixIcon: const Icon(Icons.search_rounded),
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
                SizedBox(
                  width: constraints.maxWidth >= 700
                      ? 230
                      : constraints.maxWidth,
                  child: DropdownButtonFormField<String?>(
                    isExpanded: true,
                    initialValue: _categoryId,
                    decoration: InputDecoration(labelText: l.category),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(l.allCategories),
                      ),
                      for (final category in widget.controller.categories)
                        DropdownMenuItem(
                          value: category.id,
                          child: Text(category.name),
                        ),
                    ],
                    onChanged: (value) => setState(() => _categoryId = value),
                  ),
                ),
                FilterChip(
                  selected: _favouritesOnly,
                  avatar: const Icon(Icons.star_outline_rounded),
                  label: Text(l.favourites),
                  onSelected: (value) =>
                      setState(() => _favouritesOnly = value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (widget.controller.items.isEmpty)
            _EmptyItems(onAdd: _openEditor)
          else if (filtered.isEmpty)
            _MessageCard(
              icon: Icons.search_off_rounded,
              title: l.noItemsFound,
              body: l.itemsSubtitle,
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 900
                    ? 3
                    : constraints.maxWidth >= 560
                    ? 2
                    : 1;
                final width =
                    (constraints.maxWidth - (columns - 1) * 14) / columns;
                return Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    for (final item in filtered)
                      SizedBox(
                        width: width,
                        child: _ItemCard(
                          item: item,
                          onEdit: () => _openEditor(item),
                          onRemove: () => _confirmRemove(item),
                        ),
                      ),
                  ],
                );
              },
            ),
          if (widget.controller.saveFailed) ...[
            const SizedBox(height: 16),
            _ErrorBanner(message: l.saveError),
          ],
        ],
      );
    },
  );

  Future<void> _openEditor([CatalogueItem? item]) async {
    final l = AppLocalizations.of(context);
    final name = TextEditingController(text: item?.name);
    final category = TextEditingController(text: item?.category?.name);
    var favourite = item?.isFavourite ?? false;
    var imagePath = item?.imagePath;
    var chosenImage = false;
    final formKey = GlobalKey<FormState>();
    var pickerFailed = false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(item == null ? l.addItem : l.editItem),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (imagePath != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.file(
                          File(imagePath!),
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () async {
                            try {
                              final selected = await widget.controller
                                  .chooseItemImage();
                              if (selected != null && dialogContext.mounted) {
                                if (chosenImage) {
                                  await widget.controller.discardChosenImage(
                                    imagePath,
                                  );
                                }
                                setDialogState(() {
                                  imagePath = selected;
                                  chosenImage = true;
                                  pickerFailed = false;
                                });
                              }
                            } catch (_) {
                              setDialogState(() => pickerFailed = true);
                            }
                          },
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: Text(
                            imagePath == null ? l.chooseImage : l.changeImage,
                          ),
                        ),
                        if (imagePath != null)
                          TextButton.icon(
                            onPressed: () async {
                              if (chosenImage) {
                                await widget.controller.discardChosenImage(
                                  imagePath,
                                );
                              }
                              setDialogState(() {
                                imagePath = null;
                                chosenImage = false;
                              });
                            },
                            icon: const Icon(Icons.hide_image_outlined),
                            label: Text(l.removeImage),
                          ),
                      ],
                    ),
                    if (pickerFailed) ...[
                      const SizedBox(height: 8),
                      Text(
                        l.imagePickerError,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const ValueKey('item-name'),
                      controller: name,
                      autofocus: true,
                      maxLength: 80,
                      decoration: InputDecoration(
                        labelText: l.itemName,
                        hintText: l.itemNameHint,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return l.itemRequired;
                        }
                        if (value.trim().length > 80) return l.itemNameTooLong;
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: category,
                      maxLength: 60,
                      decoration: InputDecoration(
                        labelText: l.category,
                        hintText: l.categoryHint,
                      ),
                      validator: (value) => (value?.trim().length ?? 0) > 60
                          ? l.categoryTooLong
                          : null,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: favourite,
                      title: Text(l.favouriteItem),
                      subtitle: Text(l.favouriteItemBody),
                      onChanged: (value) =>
                          setDialogState(() => favourite = value),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final succeeded = await widget.controller.saveItem(
                  existing: item,
                  name: name.text,
                  categoryName: category.text,
                  isFavourite: favourite,
                  imagePath: imagePath,
                );
                if (succeeded && dialogContext.mounted) {
                  Navigator.pop(dialogContext, true);
                } else if (dialogContext.mounted) {
                  ScaffoldMessenger.of(
                    dialogContext,
                  ).showSnackBar(SnackBar(content: Text(l.duplicateItemError)));
                }
              },
              child: Text(l.save),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 400));
    name.dispose();
    category.dispose();
    if (saved != true && chosenImage) {
      await widget.controller.discardChosenImage(imagePath);
    }
  }

  Future<void> _confirmRemove(CatalogueItem item) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.removeItemQuestion(item.name)),
        content: Text(l.removeItemBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.removeItem),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.controller.archiveItem(item);
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.onEdit,
    required this.onRemove,
  });

  final CatalogueItem item;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              _ItemImage(item: item, size: 62),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (item.isFavourite)
                          Icon(
                            Icons.star_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                      ],
                    ),
                    if (item.category != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        item.category!.name,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: l.editItem,
                onSelected: (value) => value == 'edit' ? onEdit() : onRemove(),
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: Text(l.edit)),
                  PopupMenuItem(value: 'remove', child: Text(l.removeItem)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemImage extends StatelessWidget {
  const _ItemImage({required this.item, required this.size});

  final CatalogueItem item;
  final double size;

  @override
  Widget build(BuildContext context) {
    final path = item.imagePath;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: path == null
          ? Container(
              width: size,
              height: size,
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                Icons.restaurant_menu_rounded,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            )
          : Image.file(
              File(path),
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => SizedBox(
                width: size,
                height: size,
                child: const Icon(Icons.broken_image_outlined),
              ),
            ),
    );
  }
}

class _EmptyItems extends StatelessWidget {
  const _EmptyItems({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _MessageCard(
      icon: Icons.grid_view_rounded,
      title: l.emptyItemsTitle,
      body: l.emptyItemsBody,
      action: FilledButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.add_rounded),
        label: Text(l.addItem),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            Icon(icon, size: 42, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.errorContainer,
    borderRadius: BorderRadius.circular(16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}
