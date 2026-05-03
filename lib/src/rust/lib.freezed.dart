// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'lib.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$TrackInfo {

 String get path; String? get title; String? get artist; String? get album; String? get albumArtist; int? get trackNumber; double get durationSecs; int get sampleRate; int? get bitDepth; int get channels; String get format; BigInt get fileSizeBytes;
/// Create a copy of TrackInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TrackInfoCopyWith<TrackInfo> get copyWith => _$TrackInfoCopyWithImpl<TrackInfo>(this as TrackInfo, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TrackInfo&&(identical(other.path, path) || other.path == path)&&(identical(other.title, title) || other.title == title)&&(identical(other.artist, artist) || other.artist == artist)&&(identical(other.album, album) || other.album == album)&&(identical(other.albumArtist, albumArtist) || other.albumArtist == albumArtist)&&(identical(other.trackNumber, trackNumber) || other.trackNumber == trackNumber)&&(identical(other.durationSecs, durationSecs) || other.durationSecs == durationSecs)&&(identical(other.sampleRate, sampleRate) || other.sampleRate == sampleRate)&&(identical(other.bitDepth, bitDepth) || other.bitDepth == bitDepth)&&(identical(other.channels, channels) || other.channels == channels)&&(identical(other.format, format) || other.format == format)&&(identical(other.fileSizeBytes, fileSizeBytes) || other.fileSizeBytes == fileSizeBytes));
}


@override
int get hashCode => Object.hash(runtimeType,path,title,artist,album,albumArtist,trackNumber,durationSecs,sampleRate,bitDepth,channels,format,fileSizeBytes);

@override
String toString() {
  return 'TrackInfo(path: $path, title: $title, artist: $artist, album: $album, albumArtist: $albumArtist, trackNumber: $trackNumber, durationSecs: $durationSecs, sampleRate: $sampleRate, bitDepth: $bitDepth, channels: $channels, format: $format, fileSizeBytes: $fileSizeBytes)';
}


}

/// @nodoc
abstract mixin class $TrackInfoCopyWith<$Res>  {
  factory $TrackInfoCopyWith(TrackInfo value, $Res Function(TrackInfo) _then) = _$TrackInfoCopyWithImpl;
@useResult
$Res call({
 String path, String? title, String? artist, String? album, String? albumArtist, int? trackNumber, double durationSecs, int sampleRate, int? bitDepth, int channels, String format, BigInt fileSizeBytes
});




}
/// @nodoc
class _$TrackInfoCopyWithImpl<$Res>
    implements $TrackInfoCopyWith<$Res> {
  _$TrackInfoCopyWithImpl(this._self, this._then);

  final TrackInfo _self;
  final $Res Function(TrackInfo) _then;

/// Create a copy of TrackInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? path = null,Object? title = freezed,Object? artist = freezed,Object? album = freezed,Object? albumArtist = freezed,Object? trackNumber = freezed,Object? durationSecs = null,Object? sampleRate = null,Object? bitDepth = freezed,Object? channels = null,Object? format = null,Object? fileSizeBytes = null,}) {
  return _then(_self.copyWith(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,artist: freezed == artist ? _self.artist : artist // ignore: cast_nullable_to_non_nullable
as String?,album: freezed == album ? _self.album : album // ignore: cast_nullable_to_non_nullable
as String?,albumArtist: freezed == albumArtist ? _self.albumArtist : albumArtist // ignore: cast_nullable_to_non_nullable
as String?,trackNumber: freezed == trackNumber ? _self.trackNumber : trackNumber // ignore: cast_nullable_to_non_nullable
as int?,durationSecs: null == durationSecs ? _self.durationSecs : durationSecs // ignore: cast_nullable_to_non_nullable
as double,sampleRate: null == sampleRate ? _self.sampleRate : sampleRate // ignore: cast_nullable_to_non_nullable
as int,bitDepth: freezed == bitDepth ? _self.bitDepth : bitDepth // ignore: cast_nullable_to_non_nullable
as int?,channels: null == channels ? _self.channels : channels // ignore: cast_nullable_to_non_nullable
as int,format: null == format ? _self.format : format // ignore: cast_nullable_to_non_nullable
as String,fileSizeBytes: null == fileSizeBytes ? _self.fileSizeBytes : fileSizeBytes // ignore: cast_nullable_to_non_nullable
as BigInt,
  ));
}

}


/// Adds pattern-matching-related methods to [TrackInfo].
extension TrackInfoPatterns on TrackInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TrackInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TrackInfo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TrackInfo value)  $default,){
final _that = this;
switch (_that) {
case _TrackInfo():
return $default(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TrackInfo value)?  $default,){
final _that = this;
switch (_that) {
case _TrackInfo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String path,  String? title,  String? artist,  String? album,  String? albumArtist,  int? trackNumber,  double durationSecs,  int sampleRate,  int? bitDepth,  int channels,  String format,  BigInt fileSizeBytes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TrackInfo() when $default != null:
return $default(_that.path,_that.title,_that.artist,_that.album,_that.albumArtist,_that.trackNumber,_that.durationSecs,_that.sampleRate,_that.bitDepth,_that.channels,_that.format,_that.fileSizeBytes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String path,  String? title,  String? artist,  String? album,  String? albumArtist,  int? trackNumber,  double durationSecs,  int sampleRate,  int? bitDepth,  int channels,  String format,  BigInt fileSizeBytes)  $default,) {final _that = this;
switch (_that) {
case _TrackInfo():
return $default(_that.path,_that.title,_that.artist,_that.album,_that.albumArtist,_that.trackNumber,_that.durationSecs,_that.sampleRate,_that.bitDepth,_that.channels,_that.format,_that.fileSizeBytes);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String path,  String? title,  String? artist,  String? album,  String? albumArtist,  int? trackNumber,  double durationSecs,  int sampleRate,  int? bitDepth,  int channels,  String format,  BigInt fileSizeBytes)?  $default,) {final _that = this;
switch (_that) {
case _TrackInfo() when $default != null:
return $default(_that.path,_that.title,_that.artist,_that.album,_that.albumArtist,_that.trackNumber,_that.durationSecs,_that.sampleRate,_that.bitDepth,_that.channels,_that.format,_that.fileSizeBytes);case _:
  return null;

}
}

}

/// @nodoc


class _TrackInfo implements TrackInfo {
  const _TrackInfo({required this.path, this.title, this.artist, this.album, this.albumArtist, this.trackNumber, required this.durationSecs, required this.sampleRate, this.bitDepth, required this.channels, required this.format, required this.fileSizeBytes});
  

@override final  String path;
@override final  String? title;
@override final  String? artist;
@override final  String? album;
@override final  String? albumArtist;
@override final  int? trackNumber;
@override final  double durationSecs;
@override final  int sampleRate;
@override final  int? bitDepth;
@override final  int channels;
@override final  String format;
@override final  BigInt fileSizeBytes;

/// Create a copy of TrackInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TrackInfoCopyWith<_TrackInfo> get copyWith => __$TrackInfoCopyWithImpl<_TrackInfo>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TrackInfo&&(identical(other.path, path) || other.path == path)&&(identical(other.title, title) || other.title == title)&&(identical(other.artist, artist) || other.artist == artist)&&(identical(other.album, album) || other.album == album)&&(identical(other.albumArtist, albumArtist) || other.albumArtist == albumArtist)&&(identical(other.trackNumber, trackNumber) || other.trackNumber == trackNumber)&&(identical(other.durationSecs, durationSecs) || other.durationSecs == durationSecs)&&(identical(other.sampleRate, sampleRate) || other.sampleRate == sampleRate)&&(identical(other.bitDepth, bitDepth) || other.bitDepth == bitDepth)&&(identical(other.channels, channels) || other.channels == channels)&&(identical(other.format, format) || other.format == format)&&(identical(other.fileSizeBytes, fileSizeBytes) || other.fileSizeBytes == fileSizeBytes));
}


@override
int get hashCode => Object.hash(runtimeType,path,title,artist,album,albumArtist,trackNumber,durationSecs,sampleRate,bitDepth,channels,format,fileSizeBytes);

@override
String toString() {
  return 'TrackInfo(path: $path, title: $title, artist: $artist, album: $album, albumArtist: $albumArtist, trackNumber: $trackNumber, durationSecs: $durationSecs, sampleRate: $sampleRate, bitDepth: $bitDepth, channels: $channels, format: $format, fileSizeBytes: $fileSizeBytes)';
}


}

/// @nodoc
abstract mixin class _$TrackInfoCopyWith<$Res> implements $TrackInfoCopyWith<$Res> {
  factory _$TrackInfoCopyWith(_TrackInfo value, $Res Function(_TrackInfo) _then) = __$TrackInfoCopyWithImpl;
@override @useResult
$Res call({
 String path, String? title, String? artist, String? album, String? albumArtist, int? trackNumber, double durationSecs, int sampleRate, int? bitDepth, int channels, String format, BigInt fileSizeBytes
});




}
/// @nodoc
class __$TrackInfoCopyWithImpl<$Res>
    implements _$TrackInfoCopyWith<$Res> {
  __$TrackInfoCopyWithImpl(this._self, this._then);

  final _TrackInfo _self;
  final $Res Function(_TrackInfo) _then;

/// Create a copy of TrackInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? path = null,Object? title = freezed,Object? artist = freezed,Object? album = freezed,Object? albumArtist = freezed,Object? trackNumber = freezed,Object? durationSecs = null,Object? sampleRate = null,Object? bitDepth = freezed,Object? channels = null,Object? format = null,Object? fileSizeBytes = null,}) {
  return _then(_TrackInfo(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,artist: freezed == artist ? _self.artist : artist // ignore: cast_nullable_to_non_nullable
as String?,album: freezed == album ? _self.album : album // ignore: cast_nullable_to_non_nullable
as String?,albumArtist: freezed == albumArtist ? _self.albumArtist : albumArtist // ignore: cast_nullable_to_non_nullable
as String?,trackNumber: freezed == trackNumber ? _self.trackNumber : trackNumber // ignore: cast_nullable_to_non_nullable
as int?,durationSecs: null == durationSecs ? _self.durationSecs : durationSecs // ignore: cast_nullable_to_non_nullable
as double,sampleRate: null == sampleRate ? _self.sampleRate : sampleRate // ignore: cast_nullable_to_non_nullable
as int,bitDepth: freezed == bitDepth ? _self.bitDepth : bitDepth // ignore: cast_nullable_to_non_nullable
as int?,channels: null == channels ? _self.channels : channels // ignore: cast_nullable_to_non_nullable
as int,format: null == format ? _self.format : format // ignore: cast_nullable_to_non_nullable
as String,fileSizeBytes: null == fileSizeBytes ? _self.fileSizeBytes : fileSizeBytes // ignore: cast_nullable_to_non_nullable
as BigInt,
  ));
}


}

// dart format on
