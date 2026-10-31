// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'transfer_history_session.dart';

class TransferHistoryDirectionMapper
    extends EnumMapper<TransferHistoryDirection> {
  TransferHistoryDirectionMapper._();

  static TransferHistoryDirectionMapper? _instance;
  static TransferHistoryDirectionMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(
        _instance = TransferHistoryDirectionMapper._(),
      );
    }
    return _instance!;
  }

  static TransferHistoryDirection fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  TransferHistoryDirection decode(dynamic value) {
    switch (value) {
      case r'send':
        return TransferHistoryDirection.send;
      case r'receive':
        return TransferHistoryDirection.receive;
      default:
        return TransferHistoryDirection.values[1];
    }
  }

  @override
  dynamic encode(TransferHistoryDirection self) {
    switch (self) {
      case TransferHistoryDirection.send:
        return r'send';
      case TransferHistoryDirection.receive:
        return r'receive';
    }
  }
}

extension TransferHistoryDirectionMapperExtension on TransferHistoryDirection {
  String toValue() {
    TransferHistoryDirectionMapper.ensureInitialized();
    return MapperContainer.globals.toValue<TransferHistoryDirection>(this)
        as String;
  }
}

class TransferHistoryFileMapper extends ClassMapperBase<TransferHistoryFile> {
  TransferHistoryFileMapper._();

  static TransferHistoryFileMapper? _instance;
  static TransferHistoryFileMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = TransferHistoryFileMapper._());
      FileTypeMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'TransferHistoryFile';

  static String _$id(TransferHistoryFile v) => v.id;
  static const Field<TransferHistoryFile, String> _f$id = Field('id', _$id);
  static String _$fileName(TransferHistoryFile v) => v.fileName;
  static const Field<TransferHistoryFile, String> _f$fileName = Field(
    'fileName',
    _$fileName,
  );
  static FileType _$fileType(TransferHistoryFile v) => v.fileType;
  static const Field<TransferHistoryFile, FileType> _f$fileType = Field(
    'fileType',
    _$fileType,
  );
  static int _$fileSize(TransferHistoryFile v) => v.fileSize;
  static const Field<TransferHistoryFile, int> _f$fileSize = Field(
    'fileSize',
    _$fileSize,
  );
  static String? _$path(TransferHistoryFile v) => v.path;
  static const Field<TransferHistoryFile, String> _f$path = Field(
    'path',
    _$path,
  );
  static bool _$savedToGallery(TransferHistoryFile v) => v.savedToGallery;
  static const Field<TransferHistoryFile, bool> _f$savedToGallery = Field(
    'savedToGallery',
    _$savedToGallery,
  );
  static bool _$isMessage(TransferHistoryFile v) => v.isMessage;
  static const Field<TransferHistoryFile, bool> _f$isMessage = Field(
    'isMessage',
    _$isMessage,
  );
  static DateTime? _$modified(TransferHistoryFile v) => v.modified;
  static const Field<TransferHistoryFile, DateTime> _f$modified = Field(
    'modified',
    _$modified,
  );

  @override
  final MappableFields<TransferHistoryFile> fields = const {
    #id: _f$id,
    #fileName: _f$fileName,
    #fileType: _f$fileType,
    #fileSize: _f$fileSize,
    #path: _f$path,
    #savedToGallery: _f$savedToGallery,
    #isMessage: _f$isMessage,
    #modified: _f$modified,
  };

  static TransferHistoryFile _instantiate(DecodingData data) {
    return TransferHistoryFile(
      id: data.dec(_f$id),
      fileName: data.dec(_f$fileName),
      fileType: data.dec(_f$fileType),
      fileSize: data.dec(_f$fileSize),
      path: data.dec(_f$path),
      savedToGallery: data.dec(_f$savedToGallery),
      isMessage: data.dec(_f$isMessage),
      modified: data.dec(_f$modified),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static TransferHistoryFile fromJson(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<TransferHistoryFile>(map);
  }

  static TransferHistoryFile deserialize(String json) {
    return ensureInitialized().decodeJson<TransferHistoryFile>(json);
  }
}

mixin TransferHistoryFileMappable {
  String serialize() {
    return TransferHistoryFileMapper.ensureInitialized()
        .encodeJson<TransferHistoryFile>(this as TransferHistoryFile);
  }

  Map<String, dynamic> toJson() {
    return TransferHistoryFileMapper.ensureInitialized()
        .encodeMap<TransferHistoryFile>(this as TransferHistoryFile);
  }

  TransferHistoryFileCopyWith<
    TransferHistoryFile,
    TransferHistoryFile,
    TransferHistoryFile
  >
  get copyWith =>
      _TransferHistoryFileCopyWithImpl<
        TransferHistoryFile,
        TransferHistoryFile
      >(this as TransferHistoryFile, $identity, $identity);
  @override
  String toString() {
    return TransferHistoryFileMapper.ensureInitialized().stringifyValue(
      this as TransferHistoryFile,
    );
  }

  @override
  bool operator ==(Object other) {
    return TransferHistoryFileMapper.ensureInitialized().equalsValue(
      this as TransferHistoryFile,
      other,
    );
  }

  @override
  int get hashCode {
    return TransferHistoryFileMapper.ensureInitialized().hashValue(
      this as TransferHistoryFile,
    );
  }
}

extension TransferHistoryFileValueCopy<$R, $Out>
    on ObjectCopyWith<$R, TransferHistoryFile, $Out> {
  TransferHistoryFileCopyWith<$R, TransferHistoryFile, $Out>
  get $asTransferHistoryFile => $base.as(
    (v, t, t2) => _TransferHistoryFileCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class TransferHistoryFileCopyWith<
  $R,
  $In extends TransferHistoryFile,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({
    String? id,
    String? fileName,
    FileType? fileType,
    int? fileSize,
    String? path,
    bool? savedToGallery,
    bool? isMessage,
    DateTime? modified,
  });
  TransferHistoryFileCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _TransferHistoryFileCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, TransferHistoryFile, $Out>
    implements TransferHistoryFileCopyWith<$R, TransferHistoryFile, $Out> {
  _TransferHistoryFileCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<TransferHistoryFile> $mapper =
      TransferHistoryFileMapper.ensureInitialized();
  @override
  $R call({
    String? id,
    String? fileName,
    FileType? fileType,
    int? fileSize,
    Object? path = $none,
    bool? savedToGallery,
    bool? isMessage,
    Object? modified = $none,
  }) => $apply(
    FieldCopyWithData({
      if (id != null) #id: id,
      if (fileName != null) #fileName: fileName,
      if (fileType != null) #fileType: fileType,
      if (fileSize != null) #fileSize: fileSize,
      if (path != $none) #path: path,
      if (savedToGallery != null) #savedToGallery: savedToGallery,
      if (isMessage != null) #isMessage: isMessage,
      if (modified != $none) #modified: modified,
    }),
  );
  @override
  TransferHistoryFile $make(CopyWithData data) => TransferHistoryFile(
    id: data.get(#id, or: $value.id),
    fileName: data.get(#fileName, or: $value.fileName),
    fileType: data.get(#fileType, or: $value.fileType),
    fileSize: data.get(#fileSize, or: $value.fileSize),
    path: data.get(#path, or: $value.path),
    savedToGallery: data.get(#savedToGallery, or: $value.savedToGallery),
    isMessage: data.get(#isMessage, or: $value.isMessage),
    modified: data.get(#modified, or: $value.modified),
  );

  @override
  TransferHistoryFileCopyWith<$R2, TransferHistoryFile, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _TransferHistoryFileCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class TransferHistorySessionMapper
    extends ClassMapperBase<TransferHistorySession> {
  TransferHistorySessionMapper._();

  static TransferHistorySessionMapper? _instance;
  static TransferHistorySessionMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = TransferHistorySessionMapper._());
      TransferHistoryDirectionMapper.ensureInitialized();
      TransferHistoryFileMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'TransferHistorySession';

  static String _$id(TransferHistorySession v) => v.id;
  static const Field<TransferHistorySession, String> _f$id = Field('id', _$id);
  static String _$peerAlias(TransferHistorySession v) => v.peerAlias;
  static const Field<TransferHistorySession, String> _f$peerAlias = Field(
    'peerAlias',
    _$peerAlias,
  );
  static TransferHistoryDirection _$direction(TransferHistorySession v) =>
      v.direction;
  static const Field<TransferHistorySession, TransferHistoryDirection>
  _f$direction = Field('direction', _$direction);
  static DateTime _$timestamp(TransferHistorySession v) => v.timestamp;
  static const Field<TransferHistorySession, DateTime> _f$timestamp = Field(
    'timestamp',
    _$timestamp,
  );
  static List<TransferHistoryFile> _$files(TransferHistorySession v) => v.files;
  static const Field<TransferHistorySession, List<TransferHistoryFile>>
  _f$files = Field('files', _$files);

  @override
  final MappableFields<TransferHistorySession> fields = const {
    #id: _f$id,
    #peerAlias: _f$peerAlias,
    #direction: _f$direction,
    #timestamp: _f$timestamp,
    #files: _f$files,
  };

  static TransferHistorySession _instantiate(DecodingData data) {
    return TransferHistorySession(
      id: data.dec(_f$id),
      peerAlias: data.dec(_f$peerAlias),
      direction: data.dec(_f$direction),
      timestamp: data.dec(_f$timestamp),
      files: data.dec(_f$files),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static TransferHistorySession fromJson(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<TransferHistorySession>(map);
  }

  static TransferHistorySession deserialize(String json) {
    return ensureInitialized().decodeJson<TransferHistorySession>(json);
  }
}

mixin TransferHistorySessionMappable {
  String serialize() {
    return TransferHistorySessionMapper.ensureInitialized()
        .encodeJson<TransferHistorySession>(this as TransferHistorySession);
  }

  Map<String, dynamic> toJson() {
    return TransferHistorySessionMapper.ensureInitialized()
        .encodeMap<TransferHistorySession>(this as TransferHistorySession);
  }

  TransferHistorySessionCopyWith<
    TransferHistorySession,
    TransferHistorySession,
    TransferHistorySession
  >
  get copyWith =>
      _TransferHistorySessionCopyWithImpl<
        TransferHistorySession,
        TransferHistorySession
      >(this as TransferHistorySession, $identity, $identity);
  @override
  String toString() {
    return TransferHistorySessionMapper.ensureInitialized().stringifyValue(
      this as TransferHistorySession,
    );
  }

  @override
  bool operator ==(Object other) {
    return TransferHistorySessionMapper.ensureInitialized().equalsValue(
      this as TransferHistorySession,
      other,
    );
  }

  @override
  int get hashCode {
    return TransferHistorySessionMapper.ensureInitialized().hashValue(
      this as TransferHistorySession,
    );
  }
}

extension TransferHistorySessionValueCopy<$R, $Out>
    on ObjectCopyWith<$R, TransferHistorySession, $Out> {
  TransferHistorySessionCopyWith<$R, TransferHistorySession, $Out>
  get $asTransferHistorySession => $base.as(
    (v, t, t2) => _TransferHistorySessionCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class TransferHistorySessionCopyWith<
  $R,
  $In extends TransferHistorySession,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<
    $R,
    TransferHistoryFile,
    TransferHistoryFileCopyWith<$R, TransferHistoryFile, TransferHistoryFile>
  >
  get files;
  $R call({
    String? id,
    String? peerAlias,
    TransferHistoryDirection? direction,
    DateTime? timestamp,
    List<TransferHistoryFile>? files,
  });
  TransferHistorySessionCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _TransferHistorySessionCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, TransferHistorySession, $Out>
    implements
        TransferHistorySessionCopyWith<$R, TransferHistorySession, $Out> {
  _TransferHistorySessionCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<TransferHistorySession> $mapper =
      TransferHistorySessionMapper.ensureInitialized();
  @override
  ListCopyWith<
    $R,
    TransferHistoryFile,
    TransferHistoryFileCopyWith<$R, TransferHistoryFile, TransferHistoryFile>
  >
  get files => ListCopyWith(
    $value.files,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(files: v),
  );
  @override
  $R call({
    String? id,
    String? peerAlias,
    TransferHistoryDirection? direction,
    DateTime? timestamp,
    List<TransferHistoryFile>? files,
  }) => $apply(
    FieldCopyWithData({
      if (id != null) #id: id,
      if (peerAlias != null) #peerAlias: peerAlias,
      if (direction != null) #direction: direction,
      if (timestamp != null) #timestamp: timestamp,
      if (files != null) #files: files,
    }),
  );
  @override
  TransferHistorySession $make(CopyWithData data) => TransferHistorySession(
    id: data.get(#id, or: $value.id),
    peerAlias: data.get(#peerAlias, or: $value.peerAlias),
    direction: data.get(#direction, or: $value.direction),
    timestamp: data.get(#timestamp, or: $value.timestamp),
    files: data.get(#files, or: $value.files),
  );

  @override
  TransferHistorySessionCopyWith<$R2, TransferHistorySession, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _TransferHistorySessionCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

