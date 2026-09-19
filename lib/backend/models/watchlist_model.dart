import 'package:equatable/equatable.dart';

class WatchlistModel extends Equatable {
  final String id;
  final String name;
  final List<String> symbols;

  const WatchlistModel({
    required this.id,
    required this.name,
    required this.symbols,
  });

  WatchlistModel copyWith({String? name, List<String>? symbols}) =>
      WatchlistModel(
        id: id,
        name: name ?? this.name,
        symbols: symbols ?? this.symbols,
      );

  @override
  List<Object?> get props => [id, name, symbols];
}
