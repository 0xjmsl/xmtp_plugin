// This is a generated file - do not edit.
//
// Generated from content.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'content.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'content.pbenum.dart';

/// ContentTypeId is used to identify the type of content stored in a Message.
class ContentTypeId extends $pb.GeneratedMessage {
  factory ContentTypeId({
    $core.String? authorityId,
    $core.String? typeId,
    $core.int? versionMajor,
    $core.int? versionMinor,
  }) {
    final result = create();
    if (authorityId != null) result.authorityId = authorityId;
    if (typeId != null) result.typeId = typeId;
    if (versionMajor != null) result.versionMajor = versionMajor;
    if (versionMinor != null) result.versionMinor = versionMinor;
    return result;
  }

  ContentTypeId._();

  factory ContentTypeId.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ContentTypeId.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ContentTypeId',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'xmtp.message_contents'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'authorityId')
    ..aOS(2, _omitFieldNames ? '' : 'typeId')
    ..aI(3, _omitFieldNames ? '' : 'versionMajor',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(4, _omitFieldNames ? '' : 'versionMinor',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ContentTypeId clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ContentTypeId copyWith(void Function(ContentTypeId) updates) =>
      super.copyWith((message) => updates(message as ContentTypeId))
          as ContentTypeId;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ContentTypeId create() => ContentTypeId._();
  @$core.override
  ContentTypeId createEmptyInstance() => create();
  static $pb.PbList<ContentTypeId> createRepeated() =>
      $pb.PbList<ContentTypeId>();
  @$core.pragma('dart2js:noInline')
  static ContentTypeId getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ContentTypeId>(create);
  static ContentTypeId? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get authorityId => $_getSZ(0);
  @$pb.TagNumber(1)
  set authorityId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAuthorityId() => $_has(0);
  @$pb.TagNumber(1)
  void clearAuthorityId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get typeId => $_getSZ(1);
  @$pb.TagNumber(2)
  set typeId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTypeId() => $_has(1);
  @$pb.TagNumber(2)
  void clearTypeId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get versionMajor => $_getIZ(2);
  @$pb.TagNumber(3)
  set versionMajor($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasVersionMajor() => $_has(2);
  @$pb.TagNumber(3)
  void clearVersionMajor() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get versionMinor => $_getIZ(3);
  @$pb.TagNumber(4)
  set versionMinor($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasVersionMinor() => $_has(3);
  @$pb.TagNumber(4)
  void clearVersionMinor() => $_clearField(4);
}

/// EncodedContent bundles the content with metadata identifying its type
/// and parameters required for correct decoding and presentation of the content.
class EncodedContent extends $pb.GeneratedMessage {
  factory EncodedContent({
    ContentTypeId? type,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? parameters,
    $core.String? fallback,
    $core.List<$core.int>? content,
    Compression? compression,
  }) {
    final result = create();
    if (type != null) result.type = type;
    if (parameters != null) result.parameters.addEntries(parameters);
    if (fallback != null) result.fallback = fallback;
    if (content != null) result.content = content;
    if (compression != null) result.compression = compression;
    return result;
  }

  EncodedContent._();

  factory EncodedContent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory EncodedContent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EncodedContent',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'xmtp.message_contents'),
      createEmptyInstance: create)
    ..aOM<ContentTypeId>(1, _omitFieldNames ? '' : 'type',
        subBuilder: ContentTypeId.create)
    ..m<$core.String, $core.String>(2, _omitFieldNames ? '' : 'parameters',
        entryClassName: 'EncodedContent.ParametersEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('xmtp.message_contents'))
    ..aOS(3, _omitFieldNames ? '' : 'fallback')
    ..a<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'content', $pb.PbFieldType.OY)
    ..aE<Compression>(5, _omitFieldNames ? '' : 'compression',
        enumValues: Compression.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EncodedContent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EncodedContent copyWith(void Function(EncodedContent) updates) =>
      super.copyWith((message) => updates(message as EncodedContent))
          as EncodedContent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EncodedContent create() => EncodedContent._();
  @$core.override
  EncodedContent createEmptyInstance() => create();
  static $pb.PbList<EncodedContent> createRepeated() =>
      $pb.PbList<EncodedContent>();
  @$core.pragma('dart2js:noInline')
  static EncodedContent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EncodedContent>(create);
  static EncodedContent? _defaultInstance;

  /// content type identifier used to match the payload with
  /// the correct decoding machinery
  @$pb.TagNumber(1)
  ContentTypeId get type => $_getN(0);
  @$pb.TagNumber(1)
  set type(ContentTypeId value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasType() => $_has(0);
  @$pb.TagNumber(1)
  void clearType() => $_clearField(1);
  @$pb.TagNumber(1)
  ContentTypeId ensureType() => $_ensure(0);

  /// optional encoding parameters required to correctly decode the content
  @$pb.TagNumber(2)
  $pb.PbMap<$core.String, $core.String> get parameters => $_getMap(1);

  /// optional fallback description of the content that can be used in case
  /// the client cannot decode or render the content
  @$pb.TagNumber(3)
  $core.String get fallback => $_getSZ(2);
  @$pb.TagNumber(3)
  set fallback($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFallback() => $_has(2);
  @$pb.TagNumber(3)
  void clearFallback() => $_clearField(3);

  /// encoded content itself
  @$pb.TagNumber(4)
  $core.List<$core.int> get content => $_getN(3);
  @$pb.TagNumber(4)
  set content($core.List<$core.int> value) => $_setBytes(3, value);
  @$pb.TagNumber(4)
  $core.bool hasContent() => $_has(3);
  @$pb.TagNumber(4)
  void clearContent() => $_clearField(4);

  /// optional compression; the value indicates algorithm used to
  /// compress the encoded content bytes
  @$pb.TagNumber(5)
  Compression get compression => $_getN(4);
  @$pb.TagNumber(5)
  set compression(Compression value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasCompression() => $_has(4);
  @$pb.TagNumber(5)
  void clearCompression() => $_clearField(5);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
