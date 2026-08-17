import 'package:open_space_parking/core/utils/file_bytes_reader_stub.dart'
    if (dart.library.io) 'package:open_space_parking/core/utils/file_bytes_reader_io.dart'
    as impl;

Future<List<int>> readFileBytes(String path) => impl.readFileBytes(path);
