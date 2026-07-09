import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final navigationStateProvider = StateProvider<int>((ref) {
  return 0;
});

final navigationScaffoldKeyProvider = Provider((ref) => GlobalKey<ScaffoldState>());
