// This is a generated file - do not edit.
//
// Generated from mls/message_contents/transcript_messages.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

/// A group member and affected installation IDs
class MembershipChange extends $pb.GeneratedMessage {
  factory MembershipChange({
    $core.Iterable<$core.List<$core.int>>? installationIds,
    $core.String? accountAddress,
    $core.String? initiatedByAccountAddress,
  }) {
    final result = create();
    if (installationIds != null) result.installationIds.addAll(installationIds);
    if (accountAddress != null) result.accountAddress = accountAddress;
    if (initiatedByAccountAddress != null)
      result.initiatedByAccountAddress = initiatedByAccountAddress;
    return result;
  }

  MembershipChange._();

  factory MembershipChange.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MembershipChange.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MembershipChange',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'xmtp.mls.message_contents'),
      createEmptyInstance: create)
    ..p<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'installationIds', $pb.PbFieldType.PY)
    ..aOS(2, _omitFieldNames ? '' : 'accountAddress')
    ..aOS(3, _omitFieldNames ? '' : 'initiatedByAccountAddress')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MembershipChange clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MembershipChange copyWith(void Function(MembershipChange) updates) =>
      super.copyWith((message) => updates(message as MembershipChange))
          as MembershipChange;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MembershipChange create() => MembershipChange._();
  @$core.override
  MembershipChange createEmptyInstance() => create();
  static $pb.PbList<MembershipChange> createRepeated() =>
      $pb.PbList<MembershipChange>();
  @$core.pragma('dart2js:noInline')
  static MembershipChange getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MembershipChange>(create);
  static MembershipChange? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$core.List<$core.int>> get installationIds => $_getList(0);

  @$pb.TagNumber(2)
  $core.String get accountAddress => $_getSZ(1);
  @$pb.TagNumber(2)
  set accountAddress($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAccountAddress() => $_has(1);
  @$pb.TagNumber(2)
  void clearAccountAddress() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get initiatedByAccountAddress => $_getSZ(2);
  @$pb.TagNumber(3)
  set initiatedByAccountAddress($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasInitiatedByAccountAddress() => $_has(2);
  @$pb.TagNumber(3)
  void clearInitiatedByAccountAddress() => $_clearField(3);
}

/// The group membership change proto
class GroupMembershipChanges extends $pb.GeneratedMessage {
  factory GroupMembershipChanges({
    $core.Iterable<MembershipChange>? membersAdded,
    $core.Iterable<MembershipChange>? membersRemoved,
    $core.Iterable<MembershipChange>? installationsAdded,
    $core.Iterable<MembershipChange>? installationsRemoved,
  }) {
    final result = create();
    if (membersAdded != null) result.membersAdded.addAll(membersAdded);
    if (membersRemoved != null) result.membersRemoved.addAll(membersRemoved);
    if (installationsAdded != null)
      result.installationsAdded.addAll(installationsAdded);
    if (installationsRemoved != null)
      result.installationsRemoved.addAll(installationsRemoved);
    return result;
  }

  GroupMembershipChanges._();

  factory GroupMembershipChanges.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GroupMembershipChanges.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GroupMembershipChanges',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'xmtp.mls.message_contents'),
      createEmptyInstance: create)
    ..pPM<MembershipChange>(1, _omitFieldNames ? '' : 'membersAdded',
        subBuilder: MembershipChange.create)
    ..pPM<MembershipChange>(2, _omitFieldNames ? '' : 'membersRemoved',
        subBuilder: MembershipChange.create)
    ..pPM<MembershipChange>(3, _omitFieldNames ? '' : 'installationsAdded',
        subBuilder: MembershipChange.create)
    ..pPM<MembershipChange>(4, _omitFieldNames ? '' : 'installationsRemoved',
        subBuilder: MembershipChange.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GroupMembershipChanges clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GroupMembershipChanges copyWith(
          void Function(GroupMembershipChanges) updates) =>
      super.copyWith((message) => updates(message as GroupMembershipChanges))
          as GroupMembershipChanges;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GroupMembershipChanges create() => GroupMembershipChanges._();
  @$core.override
  GroupMembershipChanges createEmptyInstance() => create();
  static $pb.PbList<GroupMembershipChanges> createRepeated() =>
      $pb.PbList<GroupMembershipChanges>();
  @$core.pragma('dart2js:noInline')
  static GroupMembershipChanges getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GroupMembershipChanges>(create);
  static GroupMembershipChanges? _defaultInstance;

  /// Members that have been added in the commit
  @$pb.TagNumber(1)
  $pb.PbList<MembershipChange> get membersAdded => $_getList(0);

  /// Members that have been removed in the commit
  @$pb.TagNumber(2)
  $pb.PbList<MembershipChange> get membersRemoved => $_getList(1);

  /// Installations that have been added in the commit, grouped by member
  @$pb.TagNumber(3)
  $pb.PbList<MembershipChange> get installationsAdded => $_getList(2);

  /// Installations removed in the commit, grouped by member
  @$pb.TagNumber(4)
  $pb.PbList<MembershipChange> get installationsRemoved => $_getList(3);
}

/// An inbox that was added or removed in this commit
class GroupUpdated_Inbox extends $pb.GeneratedMessage {
  factory GroupUpdated_Inbox({
    $core.String? inboxId,
  }) {
    final result = create();
    if (inboxId != null) result.inboxId = inboxId;
    return result;
  }

  GroupUpdated_Inbox._();

  factory GroupUpdated_Inbox.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GroupUpdated_Inbox.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GroupUpdated.Inbox',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'xmtp.mls.message_contents'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'inboxId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GroupUpdated_Inbox clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GroupUpdated_Inbox copyWith(void Function(GroupUpdated_Inbox) updates) =>
      super.copyWith((message) => updates(message as GroupUpdated_Inbox))
          as GroupUpdated_Inbox;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GroupUpdated_Inbox create() => GroupUpdated_Inbox._();
  @$core.override
  GroupUpdated_Inbox createEmptyInstance() => create();
  static $pb.PbList<GroupUpdated_Inbox> createRepeated() =>
      $pb.PbList<GroupUpdated_Inbox>();
  @$core.pragma('dart2js:noInline')
  static GroupUpdated_Inbox getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GroupUpdated_Inbox>(create);
  static GroupUpdated_Inbox? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get inboxId => $_getSZ(0);
  @$pb.TagNumber(1)
  set inboxId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasInboxId() => $_has(0);
  @$pb.TagNumber(1)
  void clearInboxId() => $_clearField(1);
}

/// A summary of a change to the mutable metadata
class GroupUpdated_MetadataFieldChange extends $pb.GeneratedMessage {
  factory GroupUpdated_MetadataFieldChange({
    $core.String? fieldName,
    $core.String? oldValue,
    $core.String? newValue,
  }) {
    final result = create();
    if (fieldName != null) result.fieldName = fieldName;
    if (oldValue != null) result.oldValue = oldValue;
    if (newValue != null) result.newValue = newValue;
    return result;
  }

  GroupUpdated_MetadataFieldChange._();

  factory GroupUpdated_MetadataFieldChange.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GroupUpdated_MetadataFieldChange.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GroupUpdated.MetadataFieldChange',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'xmtp.mls.message_contents'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'fieldName')
    ..aOS(2, _omitFieldNames ? '' : 'oldValue')
    ..aOS(3, _omitFieldNames ? '' : 'newValue')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GroupUpdated_MetadataFieldChange clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GroupUpdated_MetadataFieldChange copyWith(
          void Function(GroupUpdated_MetadataFieldChange) updates) =>
      super.copyWith(
              (message) => updates(message as GroupUpdated_MetadataFieldChange))
          as GroupUpdated_MetadataFieldChange;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GroupUpdated_MetadataFieldChange create() =>
      GroupUpdated_MetadataFieldChange._();
  @$core.override
  GroupUpdated_MetadataFieldChange createEmptyInstance() => create();
  static $pb.PbList<GroupUpdated_MetadataFieldChange> createRepeated() =>
      $pb.PbList<GroupUpdated_MetadataFieldChange>();
  @$core.pragma('dart2js:noInline')
  static GroupUpdated_MetadataFieldChange getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GroupUpdated_MetadataFieldChange>(
          create);
  static GroupUpdated_MetadataFieldChange? _defaultInstance;

  /// The field that was changed
  @$pb.TagNumber(1)
  $core.String get fieldName => $_getSZ(0);
  @$pb.TagNumber(1)
  set fieldName($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFieldName() => $_has(0);
  @$pb.TagNumber(1)
  void clearFieldName() => $_clearField(1);

  /// The previous value
  @$pb.TagNumber(2)
  $core.String get oldValue => $_getSZ(1);
  @$pb.TagNumber(2)
  set oldValue($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasOldValue() => $_has(1);
  @$pb.TagNumber(2)
  void clearOldValue() => $_clearField(2);

  /// The updated value
  @$pb.TagNumber(3)
  $core.String get newValue => $_getSZ(2);
  @$pb.TagNumber(3)
  set newValue($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasNewValue() => $_has(2);
  @$pb.TagNumber(3)
  void clearNewValue() => $_clearField(3);
}

/// A summary of the changes in a commit.
/// Includes added/removed inboxes and changes to metadata
class GroupUpdated extends $pb.GeneratedMessage {
  factory GroupUpdated({
    $core.String? initiatedByInboxId,
    $core.Iterable<GroupUpdated_Inbox>? addedInboxes,
    $core.Iterable<GroupUpdated_Inbox>? removedInboxes,
    $core.Iterable<GroupUpdated_MetadataFieldChange>? metadataFieldChanges,
    $core.Iterable<GroupUpdated_Inbox>? leftInboxes,
  }) {
    final result = create();
    if (initiatedByInboxId != null)
      result.initiatedByInboxId = initiatedByInboxId;
    if (addedInboxes != null) result.addedInboxes.addAll(addedInboxes);
    if (removedInboxes != null) result.removedInboxes.addAll(removedInboxes);
    if (metadataFieldChanges != null)
      result.metadataFieldChanges.addAll(metadataFieldChanges);
    if (leftInboxes != null) result.leftInboxes.addAll(leftInboxes);
    return result;
  }

  GroupUpdated._();

  factory GroupUpdated.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GroupUpdated.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GroupUpdated',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'xmtp.mls.message_contents'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'initiatedByInboxId')
    ..pPM<GroupUpdated_Inbox>(2, _omitFieldNames ? '' : 'addedInboxes',
        subBuilder: GroupUpdated_Inbox.create)
    ..pPM<GroupUpdated_Inbox>(3, _omitFieldNames ? '' : 'removedInboxes',
        subBuilder: GroupUpdated_Inbox.create)
    ..pPM<GroupUpdated_MetadataFieldChange>(
        4, _omitFieldNames ? '' : 'metadataFieldChanges',
        subBuilder: GroupUpdated_MetadataFieldChange.create)
    ..pPM<GroupUpdated_Inbox>(5, _omitFieldNames ? '' : 'leftInboxes',
        subBuilder: GroupUpdated_Inbox.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GroupUpdated clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GroupUpdated copyWith(void Function(GroupUpdated) updates) =>
      super.copyWith((message) => updates(message as GroupUpdated))
          as GroupUpdated;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GroupUpdated create() => GroupUpdated._();
  @$core.override
  GroupUpdated createEmptyInstance() => create();
  static $pb.PbList<GroupUpdated> createRepeated() =>
      $pb.PbList<GroupUpdated>();
  @$core.pragma('dart2js:noInline')
  static GroupUpdated getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GroupUpdated>(create);
  static GroupUpdated? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get initiatedByInboxId => $_getSZ(0);
  @$pb.TagNumber(1)
  set initiatedByInboxId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasInitiatedByInboxId() => $_has(0);
  @$pb.TagNumber(1)
  void clearInitiatedByInboxId() => $_clearField(1);

  /// The inboxes added in the commit
  @$pb.TagNumber(2)
  $pb.PbList<GroupUpdated_Inbox> get addedInboxes => $_getList(1);

  /// The inboxes removed in the commit
  @$pb.TagNumber(3)
  $pb.PbList<GroupUpdated_Inbox> get removedInboxes => $_getList(2);

  /// The metadata changes in the commit
  @$pb.TagNumber(4)
  $pb.PbList<GroupUpdated_MetadataFieldChange> get metadataFieldChanges =>
      $_getList(3);

  /// / The inboxes that were removed from the group in response to pending-remove/self-remove requests
  @$pb.TagNumber(5)
  $pb.PbList<GroupUpdated_Inbox> get leftInboxes => $_getList(4);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
