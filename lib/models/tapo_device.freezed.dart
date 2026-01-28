// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'tapo_device.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$TapoDevice {

 String get ip; String get nickname; String get model; bool get deviceOn; bool get isOnline;
/// Create a copy of TapoDevice
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TapoDeviceCopyWith<TapoDevice> get copyWith => _$TapoDeviceCopyWithImpl<TapoDevice>(this as TapoDevice, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TapoDevice&&(identical(other.ip, ip) || other.ip == ip)&&(identical(other.nickname, nickname) || other.nickname == nickname)&&(identical(other.model, model) || other.model == model)&&(identical(other.deviceOn, deviceOn) || other.deviceOn == deviceOn)&&(identical(other.isOnline, isOnline) || other.isOnline == isOnline));
}


@override
int get hashCode => Object.hash(runtimeType,ip,nickname,model,deviceOn,isOnline);

@override
String toString() {
  return 'TapoDevice(ip: $ip, nickname: $nickname, model: $model, deviceOn: $deviceOn, isOnline: $isOnline)';
}


}

/// @nodoc
abstract mixin class $TapoDeviceCopyWith<$Res>  {
  factory $TapoDeviceCopyWith(TapoDevice value, $Res Function(TapoDevice) _then) = _$TapoDeviceCopyWithImpl;
@useResult
$Res call({
 String ip, String nickname, String model, bool deviceOn, bool isOnline
});




}
/// @nodoc
class _$TapoDeviceCopyWithImpl<$Res>
    implements $TapoDeviceCopyWith<$Res> {
  _$TapoDeviceCopyWithImpl(this._self, this._then);

  final TapoDevice _self;
  final $Res Function(TapoDevice) _then;

/// Create a copy of TapoDevice
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? ip = null,Object? nickname = null,Object? model = null,Object? deviceOn = null,Object? isOnline = null,}) {
  return _then(_self.copyWith(
ip: null == ip ? _self.ip : ip // ignore: cast_nullable_to_non_nullable
as String,nickname: null == nickname ? _self.nickname : nickname // ignore: cast_nullable_to_non_nullable
as String,model: null == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String,deviceOn: null == deviceOn ? _self.deviceOn : deviceOn // ignore: cast_nullable_to_non_nullable
as bool,isOnline: null == isOnline ? _self.isOnline : isOnline // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [TapoDevice].
extension TapoDevicePatterns on TapoDevice {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TapoDevice value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TapoDevice() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TapoDevice value)  $default,){
final _that = this;
switch (_that) {
case _TapoDevice():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TapoDevice value)?  $default,){
final _that = this;
switch (_that) {
case _TapoDevice() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String ip,  String nickname,  String model,  bool deviceOn,  bool isOnline)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TapoDevice() when $default != null:
return $default(_that.ip,_that.nickname,_that.model,_that.deviceOn,_that.isOnline);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String ip,  String nickname,  String model,  bool deviceOn,  bool isOnline)  $default,) {final _that = this;
switch (_that) {
case _TapoDevice():
return $default(_that.ip,_that.nickname,_that.model,_that.deviceOn,_that.isOnline);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String ip,  String nickname,  String model,  bool deviceOn,  bool isOnline)?  $default,) {final _that = this;
switch (_that) {
case _TapoDevice() when $default != null:
return $default(_that.ip,_that.nickname,_that.model,_that.deviceOn,_that.isOnline);case _:
  return null;

}
}

}

/// @nodoc


class _TapoDevice implements TapoDevice {
  const _TapoDevice({required this.ip, required this.nickname, required this.model, required this.deviceOn, required this.isOnline});
  

@override final  String ip;
@override final  String nickname;
@override final  String model;
@override final  bool deviceOn;
@override final  bool isOnline;

/// Create a copy of TapoDevice
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TapoDeviceCopyWith<_TapoDevice> get copyWith => __$TapoDeviceCopyWithImpl<_TapoDevice>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TapoDevice&&(identical(other.ip, ip) || other.ip == ip)&&(identical(other.nickname, nickname) || other.nickname == nickname)&&(identical(other.model, model) || other.model == model)&&(identical(other.deviceOn, deviceOn) || other.deviceOn == deviceOn)&&(identical(other.isOnline, isOnline) || other.isOnline == isOnline));
}


@override
int get hashCode => Object.hash(runtimeType,ip,nickname,model,deviceOn,isOnline);

@override
String toString() {
  return 'TapoDevice(ip: $ip, nickname: $nickname, model: $model, deviceOn: $deviceOn, isOnline: $isOnline)';
}


}

/// @nodoc
abstract mixin class _$TapoDeviceCopyWith<$Res> implements $TapoDeviceCopyWith<$Res> {
  factory _$TapoDeviceCopyWith(_TapoDevice value, $Res Function(_TapoDevice) _then) = __$TapoDeviceCopyWithImpl;
@override @useResult
$Res call({
 String ip, String nickname, String model, bool deviceOn, bool isOnline
});




}
/// @nodoc
class __$TapoDeviceCopyWithImpl<$Res>
    implements _$TapoDeviceCopyWith<$Res> {
  __$TapoDeviceCopyWithImpl(this._self, this._then);

  final _TapoDevice _self;
  final $Res Function(_TapoDevice) _then;

/// Create a copy of TapoDevice
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? ip = null,Object? nickname = null,Object? model = null,Object? deviceOn = null,Object? isOnline = null,}) {
  return _then(_TapoDevice(
ip: null == ip ? _self.ip : ip // ignore: cast_nullable_to_non_nullable
as String,nickname: null == nickname ? _self.nickname : nickname // ignore: cast_nullable_to_non_nullable
as String,model: null == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String,deviceOn: null == deviceOn ? _self.deviceOn : deviceOn // ignore: cast_nullable_to_non_nullable
as bool,isOnline: null == isOnline ? _self.isOnline : isOnline // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
