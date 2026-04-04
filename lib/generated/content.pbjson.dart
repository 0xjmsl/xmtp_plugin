// This is a generated file - do not edit.
//
// Generated from content.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use compressionDescriptor instead')
const Compression$json = {
  '1': 'Compression',
  '2': [
    {'1': 'COMPRESSION_DEFLATE', '2': 0},
    {'1': 'COMPRESSION_GZIP', '2': 1},
  ],
};

/// Descriptor for `Compression`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List compressionDescriptor = $convert.base64Decode(
    'CgtDb21wcmVzc2lvbhIXChNDT01QUkVTU0lPTl9ERUZMQVRFEAASFAoQQ09NUFJFU1NJT05fR1'
    'pJUBAB');

@$core.Deprecated('Use contentTypeIdDescriptor instead')
const ContentTypeId$json = {
  '1': 'ContentTypeId',
  '2': [
    {'1': 'authority_id', '3': 1, '4': 1, '5': 9, '10': 'authorityId'},
    {'1': 'type_id', '3': 2, '4': 1, '5': 9, '10': 'typeId'},
    {'1': 'version_major', '3': 3, '4': 1, '5': 13, '10': 'versionMajor'},
    {'1': 'version_minor', '3': 4, '4': 1, '5': 13, '10': 'versionMinor'},
  ],
};

/// Descriptor for `ContentTypeId`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List contentTypeIdDescriptor = $convert.base64Decode(
    'Cg1Db250ZW50VHlwZUlkEiEKDGF1dGhvcml0eV9pZBgBIAEoCVILYXV0aG9yaXR5SWQSFwoHdH'
    'lwZV9pZBgCIAEoCVIGdHlwZUlkEiMKDXZlcnNpb25fbWFqb3IYAyABKA1SDHZlcnNpb25NYWpv'
    'chIjCg12ZXJzaW9uX21pbm9yGAQgASgNUgx2ZXJzaW9uTWlub3I=');

@$core.Deprecated('Use encodedContentDescriptor instead')
const EncodedContent$json = {
  '1': 'EncodedContent',
  '2': [
    {
      '1': 'type',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.xmtp.message_contents.ContentTypeId',
      '10': 'type'
    },
    {
      '1': 'parameters',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.xmtp.message_contents.EncodedContent.ParametersEntry',
      '10': 'parameters'
    },
    {
      '1': 'fallback',
      '3': 3,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'fallback',
      '17': true
    },
    {
      '1': 'compression',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.xmtp.message_contents.Compression',
      '9': 1,
      '10': 'compression',
      '17': true
    },
    {'1': 'content', '3': 4, '4': 1, '5': 12, '10': 'content'},
  ],
  '3': [EncodedContent_ParametersEntry$json],
  '8': [
    {'1': '_fallback'},
    {'1': '_compression'},
  ],
};

@$core.Deprecated('Use encodedContentDescriptor instead')
const EncodedContent_ParametersEntry$json = {
  '1': 'ParametersEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `EncodedContent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List encodedContentDescriptor = $convert.base64Decode(
    'Cg5FbmNvZGVkQ29udGVudBI4CgR0eXBlGAEgASgLMiQueG10cC5tZXNzYWdlX2NvbnRlbnRzLk'
    'NvbnRlbnRUeXBlSWRSBHR5cGUSVQoKcGFyYW1ldGVycxgCIAMoCzI1LnhtdHAubWVzc2FnZV9j'
    'b250ZW50cy5FbmNvZGVkQ29udGVudC5QYXJhbWV0ZXJzRW50cnlSCnBhcmFtZXRlcnMSHwoIZm'
    'FsbGJhY2sYAyABKAlIAFIIZmFsbGJhY2uIAQESSQoLY29tcHJlc3Npb24YBSABKA4yIi54bXRw'
    'Lm1lc3NhZ2VfY29udGVudHMuQ29tcHJlc3Npb25IAVILY29tcHJlc3Npb26IAQESGAoHY29udG'
    'VudBgEIAEoDFIHY29udGVudBo9Cg9QYXJhbWV0ZXJzRW50cnkSEAoDa2V5GAEgASgJUgNrZXkS'
    'FAoFdmFsdWUYAiABKAlSBXZhbHVlOgI4AUILCglfZmFsbGJhY2tCDgoMX2NvbXByZXNzaW9u');
