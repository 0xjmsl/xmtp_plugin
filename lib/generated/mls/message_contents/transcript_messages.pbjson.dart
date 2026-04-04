// This is a generated file - do not edit.
//
// Generated from mls/message_contents/transcript_messages.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use membershipChangeDescriptor instead')
const MembershipChange$json = {
  '1': 'MembershipChange',
  '2': [
    {'1': 'installation_ids', '3': 1, '4': 3, '5': 12, '10': 'installationIds'},
    {'1': 'account_address', '3': 2, '4': 1, '5': 9, '10': 'accountAddress'},
    {
      '1': 'initiated_by_account_address',
      '3': 3,
      '4': 1,
      '5': 9,
      '10': 'initiatedByAccountAddress'
    },
  ],
};

/// Descriptor for `MembershipChange`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List membershipChangeDescriptor = $convert.base64Decode(
    'ChBNZW1iZXJzaGlwQ2hhbmdlEikKEGluc3RhbGxhdGlvbl9pZHMYASADKAxSD2luc3RhbGxhdG'
    'lvbklkcxInCg9hY2NvdW50X2FkZHJlc3MYAiABKAlSDmFjY291bnRBZGRyZXNzEj8KHGluaXRp'
    'YXRlZF9ieV9hY2NvdW50X2FkZHJlc3MYAyABKAlSGWluaXRpYXRlZEJ5QWNjb3VudEFkZHJlc3'
    'M=');

@$core.Deprecated('Use groupMembershipChangesDescriptor instead')
const GroupMembershipChanges$json = {
  '1': 'GroupMembershipChanges',
  '2': [
    {
      '1': 'members_added',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.xmtp.mls.message_contents.MembershipChange',
      '10': 'membersAdded'
    },
    {
      '1': 'members_removed',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.xmtp.mls.message_contents.MembershipChange',
      '10': 'membersRemoved'
    },
    {
      '1': 'installations_added',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.xmtp.mls.message_contents.MembershipChange',
      '10': 'installationsAdded'
    },
    {
      '1': 'installations_removed',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.xmtp.mls.message_contents.MembershipChange',
      '10': 'installationsRemoved'
    },
  ],
};

/// Descriptor for `GroupMembershipChanges`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List groupMembershipChangesDescriptor = $convert.base64Decode(
    'ChZHcm91cE1lbWJlcnNoaXBDaGFuZ2VzElAKDW1lbWJlcnNfYWRkZWQYASADKAsyKy54bXRwLm'
    '1scy5tZXNzYWdlX2NvbnRlbnRzLk1lbWJlcnNoaXBDaGFuZ2VSDG1lbWJlcnNBZGRlZBJUCg9t'
    'ZW1iZXJzX3JlbW92ZWQYAiADKAsyKy54bXRwLm1scy5tZXNzYWdlX2NvbnRlbnRzLk1lbWJlcn'
    'NoaXBDaGFuZ2VSDm1lbWJlcnNSZW1vdmVkElwKE2luc3RhbGxhdGlvbnNfYWRkZWQYAyADKAsy'
    'Ky54bXRwLm1scy5tZXNzYWdlX2NvbnRlbnRzLk1lbWJlcnNoaXBDaGFuZ2VSEmluc3RhbGxhdG'
    'lvbnNBZGRlZBJgChVpbnN0YWxsYXRpb25zX3JlbW92ZWQYBCADKAsyKy54bXRwLm1scy5tZXNz'
    'YWdlX2NvbnRlbnRzLk1lbWJlcnNoaXBDaGFuZ2VSFGluc3RhbGxhdGlvbnNSZW1vdmVk');

@$core.Deprecated('Use groupUpdatedDescriptor instead')
const GroupUpdated$json = {
  '1': 'GroupUpdated',
  '2': [
    {
      '1': 'initiated_by_inbox_id',
      '3': 1,
      '4': 1,
      '5': 9,
      '10': 'initiatedByInboxId'
    },
    {
      '1': 'added_inboxes',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.xmtp.mls.message_contents.GroupUpdated.Inbox',
      '10': 'addedInboxes'
    },
    {
      '1': 'removed_inboxes',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.xmtp.mls.message_contents.GroupUpdated.Inbox',
      '10': 'removedInboxes'
    },
    {
      '1': 'metadata_field_changes',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.xmtp.mls.message_contents.GroupUpdated.MetadataFieldChange',
      '10': 'metadataFieldChanges'
    },
    {
      '1': 'left_inboxes',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.xmtp.mls.message_contents.GroupUpdated.Inbox',
      '10': 'leftInboxes'
    },
  ],
  '3': [GroupUpdated_Inbox$json, GroupUpdated_MetadataFieldChange$json],
};

@$core.Deprecated('Use groupUpdatedDescriptor instead')
const GroupUpdated_Inbox$json = {
  '1': 'Inbox',
  '2': [
    {'1': 'inbox_id', '3': 1, '4': 1, '5': 9, '10': 'inboxId'},
  ],
};

@$core.Deprecated('Use groupUpdatedDescriptor instead')
const GroupUpdated_MetadataFieldChange$json = {
  '1': 'MetadataFieldChange',
  '2': [
    {'1': 'field_name', '3': 1, '4': 1, '5': 9, '10': 'fieldName'},
    {
      '1': 'old_value',
      '3': 2,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'oldValue',
      '17': true
    },
    {
      '1': 'new_value',
      '3': 3,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'newValue',
      '17': true
    },
  ],
  '8': [
    {'1': '_old_value'},
    {'1': '_new_value'},
  ],
};

/// Descriptor for `GroupUpdated`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List groupUpdatedDescriptor = $convert.base64Decode(
    'CgxHcm91cFVwZGF0ZWQSMQoVaW5pdGlhdGVkX2J5X2luYm94X2lkGAEgASgJUhJpbml0aWF0ZW'
    'RCeUluYm94SWQSUgoNYWRkZWRfaW5ib3hlcxgCIAMoCzItLnhtdHAubWxzLm1lc3NhZ2VfY29u'
    'dGVudHMuR3JvdXBVcGRhdGVkLkluYm94UgxhZGRlZEluYm94ZXMSVgoPcmVtb3ZlZF9pbmJveG'
    'VzGAMgAygLMi0ueG10cC5tbHMubWVzc2FnZV9jb250ZW50cy5Hcm91cFVwZGF0ZWQuSW5ib3hS'
    'DnJlbW92ZWRJbmJveGVzEnEKFm1ldGFkYXRhX2ZpZWxkX2NoYW5nZXMYBCADKAsyOy54bXRwLm'
    '1scy5tZXNzYWdlX2NvbnRlbnRzLkdyb3VwVXBkYXRlZC5NZXRhZGF0YUZpZWxkQ2hhbmdlUhRt'
    'ZXRhZGF0YUZpZWxkQ2hhbmdlcxJQCgxsZWZ0X2luYm94ZXMYBSADKAsyLS54bXRwLm1scy5tZX'
    'NzYWdlX2NvbnRlbnRzLkdyb3VwVXBkYXRlZC5JbmJveFILbGVmdEluYm94ZXMaIgoFSW5ib3gS'
    'GQoIaW5ib3hfaWQYASABKAlSB2luYm94SWQalAEKE01ldGFkYXRhRmllbGRDaGFuZ2USHQoKZm'
    'llbGRfbmFtZRgBIAEoCVIJZmllbGROYW1lEiAKCW9sZF92YWx1ZRgCIAEoCUgAUghvbGRWYWx1'
    'ZYgBARIgCgluZXdfdmFsdWUYAyABKAlIAVIIbmV3VmFsdWWIAQFCDAoKX29sZF92YWx1ZUIMCg'
    'pfbmV3X3ZhbHVl');
