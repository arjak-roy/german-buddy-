// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'speaking_session_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$speakingSessionNotifierHash() =>
    r'aca867dd6c370794a86ac45ffa567a5c1cfb38cf';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$SpeakingSessionNotifier
    extends BuildlessAutoDisposeNotifier<SpeakingSessionState> {
  late final SpeakingExercise item;

  SpeakingSessionState build(SpeakingExercise item);
}

/// See also [SpeakingSessionNotifier].
@ProviderFor(SpeakingSessionNotifier)
const speakingSessionNotifierProvider = SpeakingSessionNotifierFamily();

/// See also [SpeakingSessionNotifier].
class SpeakingSessionNotifierFamily extends Family<SpeakingSessionState> {
  /// See also [SpeakingSessionNotifier].
  const SpeakingSessionNotifierFamily();

  /// See also [SpeakingSessionNotifier].
  SpeakingSessionNotifierProvider call(SpeakingExercise item) {
    return SpeakingSessionNotifierProvider(item);
  }

  @override
  SpeakingSessionNotifierProvider getProviderOverride(
    covariant SpeakingSessionNotifierProvider provider,
  ) {
    return call(provider.item);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'speakingSessionNotifierProvider';
}

/// See also [SpeakingSessionNotifier].
class SpeakingSessionNotifierProvider
    extends
        AutoDisposeNotifierProviderImpl<
          SpeakingSessionNotifier,
          SpeakingSessionState
        > {
  /// See also [SpeakingSessionNotifier].
  SpeakingSessionNotifierProvider(SpeakingExercise item)
    : this._internal(
        () => SpeakingSessionNotifier()..item = item,
        from: speakingSessionNotifierProvider,
        name: r'speakingSessionNotifierProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$speakingSessionNotifierHash,
        dependencies: SpeakingSessionNotifierFamily._dependencies,
        allTransitiveDependencies:
            SpeakingSessionNotifierFamily._allTransitiveDependencies,
        item: item,
      );

  SpeakingSessionNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.item,
  }) : super.internal();

  final SpeakingExercise item;

  @override
  SpeakingSessionState runNotifierBuild(
    covariant SpeakingSessionNotifier notifier,
  ) {
    return notifier.build(item);
  }

  @override
  Override overrideWith(SpeakingSessionNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: SpeakingSessionNotifierProvider._internal(
        () => create()..item = item,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        item: item,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<
    SpeakingSessionNotifier,
    SpeakingSessionState
  >
  createElement() {
    return _SpeakingSessionNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SpeakingSessionNotifierProvider && other.item == item;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, item.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin SpeakingSessionNotifierRef
    on AutoDisposeNotifierProviderRef<SpeakingSessionState> {
  /// The parameter `item` of this provider.
  SpeakingExercise get item;
}

class _SpeakingSessionNotifierProviderElement
    extends
        AutoDisposeNotifierProviderElement<
          SpeakingSessionNotifier,
          SpeakingSessionState
        >
    with SpeakingSessionNotifierRef {
  _SpeakingSessionNotifierProviderElement(super.provider);

  @override
  SpeakingExercise get item => (origin as SpeakingSessionNotifierProvider).item;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
