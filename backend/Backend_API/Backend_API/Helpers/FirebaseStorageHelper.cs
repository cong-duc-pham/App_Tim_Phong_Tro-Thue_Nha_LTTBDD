namespace Backend_API.Helpers
{
    /// <summary>
    /// Legacy wrapper giữ tương thích khi migrate từ Firebase Storage sang Cloudinary.
    /// Không còn dùng Google Cloud Storage.
    /// </summary>
    [Obsolete("FirebaseStorageHelper is deprecated. Use CloudinaryStorageHelper instead.")]
    public class FirebaseStorageHelper
    {
        private readonly CloudinaryStorageHelper _cloudinary;

        public FirebaseStorageHelper(CloudinaryStorageHelper cloudinary)
        {
            _cloudinary = cloudinary;
        }

        public Task<string> GetUploadSignedUrl(string storagePath, string contentType = "image/jpeg", int expiresInMinutes = 15)
            => Task.FromResult(_cloudinary.GetUploadUrl());

        public string GetDownloadUrl(string storagePath)
            => _cloudinary.GetDownloadUrl(storagePath);

        public Task DeleteFileAsync(string storagePath)
            => _cloudinary.DeleteFileAsync(storagePath);

        public Task DeleteFolderAsync(string folderPath)
            => Task.CompletedTask;
    }
}
