// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'config_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ConfigState {

/// Stored email, to prefill the form.
 String get email; List<String> get deviceIps; bool get isSaving; String? get errorMessage;
/// Create a copy of ConfigState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConfigStateCopyWith<ConfigState> get copyWith => _$ConfigStateCopyWithImpl<ConfigState>(this as ConfigState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ConfigState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConfigState&&(identical(other.email, _this.email) || other.email == _this.email)&&const DeepCollectionEquality().equals(other.deviceIps, _this.deviceIps)&&(identical(other.isSaving, _this.isSaving) || other.isSaving == _this.isSaving)&&(identical(other.errorMessage, _this.errorMessage) || other.errorMessage == _this.errorMessage));
}


@override
int get hashCode {
  final _this = this as ConfigState;
  return Object.hash(runtimeType,_this.email,const DeepCollectionEquality().hash(_this.deviceIps),_this.isSaving,_this.errorMessage);
}

@override
String toString() {
  final _this = this as ConfigState;
  return 'ConfigState(email: ${_this.email}, deviceIps: ${_this.deviceIps}, isSaving: ${_this.isSaving}, errorMessage: ${_this.errorMessage})';
}


}

/// @nodoc
abstract mixin class $ConfigStateCopyWith<$Res>  {
  factory $ConfigStateCopyWith(ConfigState value, $Res Function(ConfigState) _then) = _$ConfigStateCopyWithImpl;
@useResult
$Res call({
 String email, List<String> deviceIps, bool isSaving, String? errorMessage
});




}
/// @nodoc
class _$ConfigStateCopyWithImpl<$Res>
    implements $ConfigStateCopyWith<$Res> {
  _$ConfigStateCopyWithImpl(this._self, this._then);

  final ConfigState _self;
  final $Res Function(ConfigState) _then;

/// Create a copy of ConfigState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? email = null,Object? deviceIps = null,Object? isSaving = null,Object? errorMessage = freezed,}) {
  return _then(ConfigState(
email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,deviceIps: null == deviceIps ? _self.deviceIps : deviceIps // ignore: cast_nullable_to_non_nullable
as List<String>,isSaving: null == isSaving ? _self.isSaving : isSaving // ignore: cast_nullable_to_non_nullable
as bool,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ConfigState].
extension ConfigStatePatterns on ConfigState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ConfigState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ConfigState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ConfigState value)  $default,){
final _that = this;
switch (_that) {
case _ConfigState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ConfigState value)?  $default,){
final _that = this;
switch (_that) {
case _ConfigState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String email,  List<String> deviceIps,  bool isSaving,  String? errorMessage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ConfigState() when $default != null:
return $default(_that.email,_that.deviceIps,_that.isSaving,_that.errorMessage);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String email,  List<String> deviceIps,  bool isSaving,  String? errorMessage)  $default,) {final _that = this;
switch (_that) {
case _ConfigState():
return $default(_that.email,_that.deviceIps,_that.isSaving,_that.errorMessage);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String email,  List<String> deviceIps,  bool isSaving,  String? errorMessage)?  $default,) {final _that = this;
switch (_that) {
case _ConfigState() when $default != null:
return $default(_that.email,_that.deviceIps,_that.isSaving,_that.errorMessage);case _:
  return null;

}
}

}

/// @nodoc


class _ConfigState implements ConfigState {
  const _ConfigState({this.email = '',  List<String> deviceIps = const <String>[], this.isSaving = false, this.errorMessage}): _deviceIps = deviceIps;
  

/// Stored email, to prefill the form.
@override@JsonKey() final  String email;
 final  List<String> _deviceIps;
@override@JsonKey() List<String> get deviceIps {
  if (_deviceIps is EqualUnmodifiableListView) return _deviceIps;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_deviceIps);
}

@override@JsonKey() final  bool isSaving;
@override final  String? errorMessage;

/// Create a copy of ConfigState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConfigStateCopyWith<_ConfigState> get copyWith => __$ConfigStateCopyWithImpl<_ConfigState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ConfigState&&(identical(other.email, email) || other.email == email)&&const DeepCollectionEquality().equals(other.deviceIps, _deviceIps)&&(identical(other.isSaving, isSaving) || other.isSaving == isSaving)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage));
}


@override
int get hashCode {
    return Object.hash(runtimeType,email,const DeepCollectionEquality().hash(_deviceIps),isSaving,errorMessage);
}

@override
String toString() {
    return 'ConfigState(email: $email, deviceIps: $deviceIps, isSaving: $isSaving, errorMessage: $errorMessage)';
}


}

/// @nodoc
abstract mixin class _$ConfigStateCopyWith<$Res> implements $ConfigStateCopyWith<$Res> {
  factory _$ConfigStateCopyWith(_ConfigState value, $Res Function(_ConfigState) _then) = __$ConfigStateCopyWithImpl;
@override @useResult
$Res call({
 String email, List<String> deviceIps, bool isSaving, String? errorMessage
});




}
/// @nodoc
class __$ConfigStateCopyWithImpl<$Res>
    implements _$ConfigStateCopyWith<$Res> {
  __$ConfigStateCopyWithImpl(this._self, this._then);

  final _ConfigState _self;
  final $Res Function(_ConfigState) _then;

/// Create a copy of ConfigState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? email = null,Object? deviceIps = null,Object? isSaving = null,Object? errorMessage = freezed,}) {
  return _then(_ConfigState(
email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,deviceIps: null == deviceIps ? _self._deviceIps : deviceIps // ignore: cast_nullable_to_non_nullable
as List<String>,isSaving: null == isSaving ? _self.isSaving : isSaving // ignore: cast_nullable_to_non_nullable
as bool,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
