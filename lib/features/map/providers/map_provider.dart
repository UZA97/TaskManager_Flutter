import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

class SelectedLocation {
  final String name;
  final LatLng position;

  const SelectedLocation({required this.name, required this.position});
}

class SelectedLocationNotifier extends Notifier<SelectedLocation?> {
  @override
  SelectedLocation? build() => null;

  void select(SelectedLocation? location) => state = location;
}

final selectedLocationProvider =
    NotifierProvider<SelectedLocationNotifier, SelectedLocation?>(
      SelectedLocationNotifier.new,
    );
