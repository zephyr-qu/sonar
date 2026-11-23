import 'package:sonar/model/state/server/receiving_file.dart';
import 'package:sonar/provider/network/server/controller/receive_controller.dart';
import 'package:sonar_isolates/model/dto/file_dto.dart';
import 'package:sonar_isolates/model/file_type.dart';
import 'package:test/test.dart';

void main() {
  group('buildHistoryFiles', () {
    test('Should record a file saved to the gallery without a path', () {
      final files = buildHistoryFiles([
        _file(id: '1', fileName: 'photo.jpg', path: null, savedToGallery: true),
      ]);

      expect(files, hasLength(1));
      expect(files.single.id, '1');
      expect(files.single.fileName, 'photo.jpg');
      expect(files.single.path, isNull);
      expect(files.single.savedToGallery, isTrue);
    });

    test('Should record a file saved to the destination directory', () {
      final files = buildHistoryFiles([
        _file(id: '1', fileName: 'document.pdf', path: '/storage/downloads/document.pdf', savedToGallery: false),
      ]);

      expect(files, hasLength(1));
      expect(files.single.path, '/storage/downloads/document.pdf');
      expect(files.single.savedToGallery, isFalse);
    });

    test('Should prefer the desired name over the sender file name', () {
      final files = buildHistoryFiles([
        _file(id: '1', fileName: 'photo.jpg', desiredName: 'photo (1).jpg', path: '/cache/photo.jpg', savedToGallery: false),
      ]);

      expect(files.single.fileName, 'photo (1).jpg');
    });

    test('Should not record a failed file', () {
      final files = buildHistoryFiles([
        _file(id: '1', fileName: 'photo.jpg', path: null, savedToGallery: false, errorMessage: 'Checksum mismatch'),
      ]);

      expect(files, isEmpty);
    });

    test('Should keep only the successfully saved files of a mixed session', () {
      final files = buildHistoryFiles([
        _file(id: '1', fileName: 'photo.jpg', path: null, savedToGallery: true),
        _file(id: '2', fileName: 'document.pdf', path: '/storage/downloads/document.pdf', savedToGallery: false),
        _file(id: '3', fileName: 'broken.zip', path: null, savedToGallery: false, errorMessage: 'Connection lost'),
      ]);

      expect(files.map((f) => f.id), ['1', '2']);
    });

    test('Should keep the accepted files of a failed session', () {
      final files = buildHistoryFiles(
        [
          _file(id: '1', fileName: 'photo.jpg', path: '/storage/downloads/photo.jpg', savedToGallery: false),
          _file(id: '2', fileName: 'broken.zip', path: null, savedToGallery: false, errorMessage: 'Insufficient storage'),
        ],
        failed: true,
      );

      expect(files.map((f) => f.id), ['1', '2']);
      expect(files.last.fileName, 'broken.zip');
    });

    test('Should leave out a file the receiver did not accept', () {
      final files = buildHistoryFiles(
        [
          _file(id: '1', fileName: 'skipped.zip', path: null, savedToGallery: false, accepted: false),
        ],
        failed: true,
      );

      expect(files, isEmpty);
    });
  });
}

ReceivingFile _file({
  required String id,
  required String fileName,
  required String? path,
  required bool savedToGallery,
  String? desiredName,
  bool accepted = true,
  String? errorMessage,
}) {
  return ReceivingFile(
    file: FileDto(
      id: id,
      fileName: fileName,
      size: 1024,
      fileType: FileType.image,
      hash: null,
      preview: null,
      metadata: null,
    ),
    token: null,
    desiredName: accepted ? desiredName ?? fileName : null,
    path: path,
    savedToGallery: savedToGallery,
    errorMessage: errorMessage,
  );
}
