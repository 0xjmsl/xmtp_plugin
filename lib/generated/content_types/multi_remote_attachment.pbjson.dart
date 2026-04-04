// This is a generated file - do not edit.
//
// Generated from content_types/multi_remote_attachment.proto.

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

@$core.Deprecated('Use multiRemoteAttachmentDescriptor instead')
const MultiRemoteAttachment$json = {
  '1': 'MultiRemoteAttachment',
  '2': [
    {
      '1': 'attachments',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.xmtp.mls.message_contents.content_types.RemoteAttachmentInfo',
      '10': 'attachments'
    },
  ],
};

/// Descriptor for `MultiRemoteAttachment`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List multiRemoteAttachmentDescriptor = $convert.base64Decode(
    'ChVNdWx0aVJlbW90ZUF0dGFjaG1lbnQSXwoLYXR0YWNobWVudHMYASADKAsyPS54bXRwLm1scy'
    '5tZXNzYWdlX2NvbnRlbnRzLmNvbnRlbnRfdHlwZXMuUmVtb3RlQXR0YWNobWVudEluZm9SC2F0'
    'dGFjaG1lbnRz');

@$core.Deprecated('Use remoteAttachmentInfoDescriptor instead')
const RemoteAttachmentInfo$json = {
  '1': 'RemoteAttachmentInfo',
  '2': [
    {'1': 'content_digest', '3': 1, '4': 1, '5': 9, '10': 'contentDigest'},
    {'1': 'secret', '3': 2, '4': 1, '5': 12, '10': 'secret'},
    {'1': 'nonce', '3': 3, '4': 1, '5': 12, '10': 'nonce'},
    {'1': 'salt', '3': 4, '4': 1, '5': 12, '10': 'salt'},
    {'1': 'scheme', '3': 5, '4': 1, '5': 9, '10': 'scheme'},
    {'1': 'url', '3': 6, '4': 1, '5': 9, '10': 'url'},
    {
      '1': 'content_length',
      '3': 7,
      '4': 1,
      '5': 13,
      '9': 0,
      '10': 'contentLength',
      '17': true
    },
    {
      '1': 'filename',
      '3': 8,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'filename',
      '17': true
    },
  ],
  '8': [
    {'1': '_content_length'},
    {'1': '_filename'},
  ],
};

/// Descriptor for `RemoteAttachmentInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List remoteAttachmentInfoDescriptor = $convert.base64Decode(
    'ChRSZW1vdGVBdHRhY2htZW50SW5mbxIlCg5jb250ZW50X2RpZ2VzdBgBIAEoCVINY29udGVudE'
    'RpZ2VzdBIWCgZzZWNyZXQYAiABKAxSBnNlY3JldBIUCgVub25jZRgDIAEoDFIFbm9uY2USEgoE'
    'c2FsdBgEIAEoDFIEc2FsdBIWCgZzY2hlbWUYBSABKAlSBnNjaGVtZRIQCgN1cmwYBiABKAlSA3'
    'VybBIqCg5jb250ZW50X2xlbmd0aBgHIAEoDUgAUg1jb250ZW50TGVuZ3RoiAEBEh8KCGZpbGVu'
    'YW1lGAggASgJSAFSCGZpbGVuYW1liAEBQhEKD19jb250ZW50X2xlbmd0aEILCglfZmlsZW5hbW'
    'U=');
