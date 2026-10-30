// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'home_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$HomeState {

 List<TapoDevice> get devices; bool get isLoading; String? get errorMessage;/// Plugs with a command in flight.
 Set<String> get toggling;/// Time left before each scheduled plug turns off.
 Map<String, Duration> get powerOffRemaining;
/// Create a copy of HomeState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HomeStateCopyWith<HomeState> get copyWith => _$HomeStateCopyWithImpl<HomeState>(this as HomeState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as HomeState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HomeState&&const DeepCollectionEquality().equals(other.devices, _this.devices)&&(identical(other.isLoading, _this.isLoading) || other.isLoading == _this.isLoading)&&(identical(other.errorMessage, _this.errorMessage) || other.errorMessage == _this.errorMessage)&&const DeepCollectionEquality().equals(other.toggling, _this.toggling)&&const DeepCollectionEquality().equals(other.powerOffRemaining, _this.powerOffRemaining));
}


@override
int get hashCode {
  final _this = this as HomeState;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.devices),_this.isLoading,_this.errorMessage,const DeepCollectionEquality().hash(_this.toggling),const DeepCollectionEquality().hash(_this.powerOffRemaining));
}

@override
String toString() {
  final _this = this as HomeState;
  return 'HomeState(devices: ${_this.devices}, isLoading: ${_this.isLoading}, errorMessage: ${_this.errorMessage}, toggling: ${_this.toggling}, powerOffRemaining: ${_this.powerOffRemaining})';
}


}

/// @nodoc
abstract mixin class $HomeStateCopyWith<$Res>  {
  factory $HomeStateCopyWith(HomeState value, $Res Function(HomeState) _then) = _$HomeStateCopyWithImpl;
@useResult
$Res call({
 List<TapoDevice> devices, bool isLoading, String? errorMessage, Set<String> toggling, Map<String, Duration> powerOffRemaining
});




}
/// @nodoc
class _$HomeStateCopyWithImpl<$Res>
    implements $HomeStateCopyWith<$Res> {
  _$HomeStateCopyWithImpl(this._self, this._then);

  final HomeState _self;
  final $Res Function(HomeState) _then;

/// Create a copy of HomeState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? devices = null,Object? isLoading = null,Object? errorMessage = freezed,Object? toggling = null,Object? powerOffRemaining = null,}) {
  return _then(HomeState(
devices: null == devices ? _self.devices : devices // ignore: cast_nullable_to_non_nullable
as List<TapoDevice>,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,toggling: null == toggling ? _self.toggling : toggling // ignore: cast_nullable_to_non_nullable
as Set<String>,powerOffRemaining: null == powerOffRemaining ? _self.powerOffRemaining : powerOffRemaining // ignore: cast_nullable_to_non_nullable
as Map<String, Duration>,
  ));
}

}


/// Adds pattern-matching-related methods to [HomeState].
extension HomeStatePatterns on HomeState {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HomeState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HomeState() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HomeState value)  $default,){
final _that = this;
switch (_that) {
case _HomeState():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HomeState value)?  $default,){
final _that = this;
switch (_that) {
case _HomeState() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<TapoDevice> devices,  bool isLoading,  String? errorMessage,  Set<String> toggling,  Map<String, Duration> powerOffRemaining)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HomeState() when $default != null:
return $default(_that.devices,_that.isLoading,_that.errorMessage,_that.toggling,_that.powerOffRemaining);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<TapoDevice> devices,  bool isLoading,  String? errorMessage,  Set<String> toggling,  Map<String, Duration> powerOffRemaining)  $default,) {final _that = this;
switch (_that) {
case _HomeState():
return $default(_that.devices,_that.isLoading,_that.errorMessage,_that.toggling,_that.powerOffRemaining);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<TapoDevice> devices,  bool isLoading,  String? errorMessage,  Set<String> toggling,  Map<String, Duration> powerOffRemaining)?  $default,) {final _that = this;
switch (_that) {
case _HomeState() when $default != null:
return $default(_that.devices,_that.isLoading,_that.errorMessage,_that.toggling,_that.powerOffRemaining);case _:
  return null;

}
}

}

/// @nodoc


class _HomeState extends HomeState {
  const _HomeState({ List<TapoDevice> devices = const [], this.isLoading = false, this.errorMessage,  Set<String> toggling = const <String>{},  Map<String, Duration> powerOffRemaining = const <String, Duration>{}}): _devices = devices,_toggling = toggling,_powerOffRemaining = powerOffRemaining,super._();
  

 final  List<TapoDevice> _devices;
@override@JsonKey() List<TapoDevice> get devices {
  if (_devices is EqualUnmodifiableListView) return _devices;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_devices);
}

@override@JsonKey() final  bool isLoading;
@override final  String? errorMessage;
/// Plugs with a command in flight.
 final  Set<String> _toggling;
/// Plugs with a command in flight.
@override@JsonKey() Set<String> get toggling {
  if (_toggling is EqualUnmodifiableSetView) return _toggling;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_toggling);
}

/// Time left before each scheduled plug turns off.
 final  Map<String, Duration> _powerOffRemaining;
/// Time left before each scheduled plug turns off.
@override@JsonKey() Map<String, Duration> get powerOffRemaining {
  if (_powerOffRemaining is EqualUnmodifiableMapView) return _powerOffRemaining;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_powerOffRemaining);
}


/// Create a copy of HomeState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HomeStateCopyWith<_HomeState> get copyWith => __$HomeStateCopyWithImpl<_HomeState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _HomeState&&const DeepCollectionEquality().equals(other.devices, _devices)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&const DeepCollectionEquality().equals(other.toggling, _toggling)&&const DeepCollectionEquality().equals(other.powerOffRemaining, _powerOffRemaining));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_devices),isLoading,errorMessage,const DeepCollectionEquality().hash(_toggling),const DeepCollectionEquality().hash(_powerOffRemaining));
}

@override
String toString() {
    return 'HomeState(devices: $devices, isLoading: $isLoading, errorMessage: $errorMessage, toggling: $toggling, powerOffRemaining: $powerOffRemaining)';
}


}

/// @nodoc
abstract mixin class _$HomeStateCopyWith<$Res> implements $HomeStateCopyWith<$Res> {
  factory _$HomeStateCopyWith(_HomeState value, $Res Function(_HomeState) _then) = __$HomeStateCopyWithImpl;
@override @useResult
$Res call({
 List<TapoDevice> devices, bool isLoading, String? errorMessage, Set<String> toggling, Map<String, Duration> powerOffRemaining
});




}
/// @nodoc
class __$HomeStateCopyWithImpl<$Res>
    implements _$HomeStateCopyWith<$Res> {
  __$HomeStateCopyWithImpl(this._self, this._then);

  final _HomeState _self;
  final $Res Function(_HomeState) _then;

/// Create a copy of HomeState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? devices = null,Object? isLoading = null,Object? errorMessage = freezed,Object? toggling = null,Object? powerOffRemaining = null,}) {
  return _then(_HomeState(
devices: null == devices ? _self._devices : devices // ignore: cast_nullable_to_non_nullable
as List<TapoDevice>,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,toggling: null == toggling ? _self._toggling : toggling // ignore: cast_nullable_to_non_nullable
as Set<String>,powerOffRemaining: null == powerOffRemaining ? _self._powerOffRemaining : powerOffRemaining // ignore: cast_nullable_to_non_nullable
as Map<String, Duration>,
  ));
}


}

// dart format on
