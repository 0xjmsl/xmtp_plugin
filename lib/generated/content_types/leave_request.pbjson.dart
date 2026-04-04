// This is a generated file - do not edit.
//
// Generated from content_types/leave_request.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use leaveRequestDescriptor instead')
const LeaveRequest$json = {
  '1': 'LeaveRequest',
  '2': [
    {
      '1': 'authenticated_note',
      '3': 1,
      '4': 1,
      '5': 12,
      '9': 0,
      '10': 'authenticatedNote',
      '17': true
    },
  ],
  '8': [
    {'1': '_authenticated_note'},
  ],
};

/// Descriptor for `LeaveRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List leaveRequestDescriptor = $convert.base64Decode(
    'CgxMZWF2ZVJlcXVlc3QSMgoSYXV0aGVudGljYXRlZF9ub3RlGAEgASgMSABSEWF1dGhlbnRpY2'
    'F0ZWROb3RliAEBQhUKE19hdXRoZW50aWNhdGVkX25vdGU=');
