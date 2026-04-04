// This is a generated file - do not edit.
//
// Generated from content_types/leave_request.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class LeaveRequest extends $pb.GeneratedMessage {
  factory LeaveRequest({
    $core.List<$core.int>? authenticatedNote,
  }) {
    final result = create();
    if (authenticatedNote != null) result.authenticatedNote = authenticatedNote;
    return result;
  }

  LeaveRequest._();

  factory LeaveRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory LeaveRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LeaveRequest',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'xmtp.mls.message_contents.content_types'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'authenticatedNote', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LeaveRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LeaveRequest copyWith(void Function(LeaveRequest) updates) =>
      super.copyWith((message) => updates(message as LeaveRequest))
          as LeaveRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LeaveRequest create() => LeaveRequest._();
  @$core.override
  LeaveRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static LeaveRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LeaveRequest>(create);
  static LeaveRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get authenticatedNote => $_getN(0);
  @$pb.TagNumber(1)
  set authenticatedNote($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAuthenticatedNote() => $_has(0);
  @$pb.TagNumber(1)
  void clearAuthenticatedNote() => $_clearField(1);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
