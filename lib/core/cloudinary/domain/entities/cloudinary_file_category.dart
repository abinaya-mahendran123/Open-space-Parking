enum CloudinaryFileCategory {
  image,
  pdf,
  document,
  any;

  String get label => switch (this) {
        CloudinaryFileCategory.image => 'Image',
        CloudinaryFileCategory.pdf => 'PDF',
        CloudinaryFileCategory.document => 'Document',
        CloudinaryFileCategory.any => 'Any file',
      };
}
