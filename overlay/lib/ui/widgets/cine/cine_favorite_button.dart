// TaquitoFlix: botón "Mi lista" (favoritos de Jellyfin) para las cabeceras.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:server_core/server_core.dart' hide ImageType;

import '../../../data/repositories/item_mutation_repository.dart';
import 'cine_widgets.dart';

class CineFavoriteButton extends StatefulWidget {
  final String itemId;

  /// Si se sabe de antemano (por ejemplo, el título viene de una fila).
  final bool? initialFavorite;
  final bool expand;
  final VoidCallback? onUpEdge;

  const CineFavoriteButton({
    super.key,
    required this.itemId,
    this.initialFavorite,
    this.expand = false,
    this.onUpEdge,
  });

  @override
  State<CineFavoriteButton> createState() => _CineFavoriteButtonState();
}

class _CineFavoriteButtonState extends State<CineFavoriteButton> {
  bool _favorite = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _favorite = widget.initialFavorite ?? false;
    if (widget.initialFavorite == null) unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant CineFavoriteButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemId != widget.itemId) {
      _favorite = widget.initialFavorite ?? false;
      if (widget.initialFavorite == null) unawaited(_load());
    }
  }

  Future<void> _load() async {
    final id = widget.itemId;
    try {
      final item = await GetIt.instance<MediaServerClient>().itemsApi.getItem(
            id,
            fields: '',
          );
      final userData = item['UserData'];
      final fav = userData is Map && userData['IsFavorite'] == true;
      if (mounted && id == widget.itemId) setState(() => _favorite = fav);
    } catch (_) {}
  }

  Future<void> _toggle() async {
    if (_busy) return;
    final next = !_favorite;
    setState(() {
      _busy = true;
      _favorite = next;
    });
    try {
      await GetIt.instance<ItemMutationRepository>().setFavorite(
        widget.itemId,
        isFavorite: next,
      );
    } catch (_) {
      if (mounted) setState(() => _favorite = !next);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CineButton(
      icon: _favorite ? Icons.check_rounded : Icons.add_rounded,
      label: cineText(context, 'Mi lista', 'My list'),
      primary: false,
      expand: widget.expand,
      onUpEdge: widget.onUpEdge,
      onTap: () => unawaited(_toggle()),
    );
  }
}
