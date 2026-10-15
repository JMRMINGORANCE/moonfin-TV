// TaquitoFlix: acciones que usa la portada (menú rápido y aviso de llegada).

import 'package:get_it/get_it.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';

import '../../../data/models/aggregated_item.dart';
import '../../../data/repositories/item_mutation_repository.dart';

/// Marca o desmarca como visto. Desmarcar también quita el título de
/// "Seguir viendo", porque el servidor borra el punto donde se quedó.
Future<void> cineSetPlayed(String itemId, {required bool played}) =>
    GetIt.instance<ItemMutationRepository>().setPlayed(itemId, isPlayed: played);

const _arrivalsKey = 'taquitoflix_arrivals_seen_at';

/// Lo que ha llegado desde la última vez que se abrió la portada, de lo más
/// nuevo a lo más viejo. La primera vez solo apunta la fecha (no avisa de
/// todo lo que ya había).
Future<List<AggregatedItem>> cineNewArrivals(List<AggregatedItem> items) async {
  final store = GetIt.instance<PreferenceStore>();
  final now = DateTime.now().toUtc();
  final raw = store.getString(_arrivalsKey);
  await store.setString(_arrivalsKey, now.toIso8601String());
  final since = raw == null ? null : DateTime.tryParse(raw);
  if (since == null) return const [];
  DateTime? created(AggregatedItem i) =>
      DateTime.tryParse(i.rawData['DateCreated']?.toString() ?? '');
  final fresh = [
    for (final i in items)
      if (created(i) != null && created(i)!.isAfter(since)) i,
  ]..sort((a, b) => created(b)!.compareTo(created(a)!));
  return fresh;
}
