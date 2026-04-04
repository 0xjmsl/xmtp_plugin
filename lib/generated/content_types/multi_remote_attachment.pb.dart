// This is a generated file - do not edit.
//
// Generated from content_types/multi_remote_attachment.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class MultiRemoteAttachment extends $pb.GeneratedMessage {
  factory MultiRemoteAttachment({
    $core.Iterable<RemoteAttachmentInfo>? attachments,
  }) {
    final result = create();
    if (attachments != null) result.attachments.addAll(attachments);
    return result;
  }

  MultiRemoteAttachment._();

  factory MultiRemoteAttachment.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MultiRemoteAttachment.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MultiRemoteAttachment',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'xmtp.mls.message_contents.content_types'),
      createEmptyInstance: create)
    ..pPM<RemoteAttachmentInfo>(1, _omitFieldNames ? '' : 'attachments',
        subBuilder: RemoteAttachmentInfo.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MultiRemoteAttachment clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MultiRemoteAttachment copyWith(
          void Function(MultiRemoteAttachment) updates) =>
      super.copyWith((message) => updates(message as MultiRemoteAttachment))
          as MultiRemoteAttachment;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MultiRemoteAttachment create() => MultiRemoteAttachment._();
  @$core.override
  MultiRemoteAttachment createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MultiRemoteAttachment getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MultiRemoteAttachment>(create);
  static MultiRemoteAttachment? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<RemoteAttachmentInfo> get attachments => $_getList(0);
}

class RemoteAttachmentInfo extends $pb.GeneratedMessage {
  factory RemoteAttachmentInfo({
    $core.String? contentDigest,
    $core.List<$core.int>? secret,
    $core.List<$core.int>? nonce,
    $core.List<$core.int>? salt,
    $core.String? scheme,
    $core.String? url,
    $core.int? contentLength,
    $core.String? filename,
  }) {
    final result = create();
    if (contentDigest != null) result.contentDigest = contentDigest;
    if (secret != null) result.secret = secret;
    if (nonce != null) result.nonce = nonce;
    if (salt != null) result.salt = salt;
    if (scheme != null) result.scheme = scheme;
    if (url != null) result.url = url;
    if (contentLength != null) result.contentLength = contentLength;
    if (filename != null) result.filename = filename;
    return result;
  }

  RemoteAttachmentInfo._();

  factory RemoteAttachmentInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RemoteAttachmentInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RemoteAttachmentInfo',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'xmtp.mls.message_contents.content_types'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'contentDigest')
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'secret', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'nonce', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'salt', $pb.PbFieldType.OY)
    ..aOS(5, _omitFieldNames ? '' : 'scheme')
    ..aOS(6, _omitFieldNames ? '' : 'url')
    ..aI(7, _omitFieldNames ? '' : 'contentLength',
        fieldType: $pb.PbFieldType.OU3)
    ..aOS(8, _omitFieldNames ? '' : 'filename')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoteAttachmentInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoteAttachmentInfo copyWith(void Function(RemoteAttachmentInfo) updates) =>
      super.copyWith((message) => updates(message as RemoteAttachmentInfo))
          as RemoteAttachmentInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RemoteAttachmentInfo create() => RemoteAttachmentInfo._();
  @$core.override
  RemoteAttachmentInfo createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RemoteAttachmentInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RemoteAttachmentInfo>(create);
  static RemoteAttachmentInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get contentDigest => $_getSZ(0);
  @$pb.TagNumber(1)
  set contentDigest($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasContentDigest() => $_has(0);
  @$pb.TagNumber(1)
  void clearContentDigest() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get secret => $_getN(1);
  @$pb.TagNumber(2)
  set secret($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSecret() => $_has(1);
  @$pb.TagNumber(2)
  void clearSecret() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get nonce => $_getN(2);
  @$pb.TagNumber(3)
  set nonce($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasNonce() => $_has(2);
  @$pb.TagNumber(3)
  void clearNonce() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get salt => $_getN(3);
  @$pb.TagNumber(4)
  set salt($core.List<$core.int> value) => $_setBytes(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSalt() => $_has(3);
  @$pb.TagNumber(4)
  void clearSalt() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get scheme => $_getSZ(4);
  @$pb.TagNumber(5)
  set scheme($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasScheme() => $_has(4);
  @$pb.TagNumber(5)
  void clearScheme() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get url => $_getSZ(5);
  @$pb.TagNumber(6)
  set url($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasUrl() => $_has(5);
  @$pb.TagNumber(6)
  void clearUrl() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get contentLength => $_getIZ(6);
  @$pb.TagNumber(7)
  set contentLength($core.int value) => $_setUnsignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasContentLength() => $_has(6);
  @$pb.TagNumber(7)
  void clearContentLength() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get filename => $_getSZ(7);
  @$pb.TagNumber(8)
  set filename($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasFilename() => $_has(7);
  @$pb.TagNumber(8)
  void clearFilename() => $_clearField(8);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
