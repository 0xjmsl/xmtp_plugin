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

/// Recognized compression algorithms
/// protolint:disable ENUM_FIELD_NAMES_ZERO_VALUE_END_WITH
class Compression extends $pb.ProtobufEnum {
  static const Compression COMPRESSION_DEFLATE =
      Compression._(0, _omitEnumNames ? '' : 'COMPRESSION_DEFLATE');
  static const Compression COMPRESSION_GZIP =
      Compression._(1, _omitEnumNames ? '' : 'COMPRESSION_GZIP');

  static const $core.List<Compression> values = <Compression>[
    COMPRESSION_DEFLATE,
    COMPRESSION_GZIP,
  ];

  static final $core.List<Compression?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 1);
  static Compression? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Compression._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
