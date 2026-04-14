using System.Security.Cryptography;
using System.Text;

namespace Backend_API.Helpers
{
    public class CloudinaryStorageHelper
    {
        private readonly string _cloudName;
        private readonly string _apiKey;
        private readonly string _apiSecret;
        private readonly string _defaultUploadPreset;
        private readonly string _listingUploadPreset;
        private readonly string _avatarUploadPreset;
        private readonly string _chatUploadPreset;

        public CloudinaryStorageHelper(IConfiguration configuration)
        {
            var section = configuration.GetSection("Cloudinary");

            _cloudName = section["CloudName"]
                ?? throw new InvalidOperationException("Cloudinary:CloudName chưa được cấu hình.");
            _apiKey = section["ApiKey"]
                ?? throw new InvalidOperationException("Cloudinary:ApiKey chưa được cấu hình.");
            _apiSecret = section["ApiSecret"]
                ?? throw new InvalidOperationException("Cloudinary:ApiSecret chưa được cấu hình.");

            _defaultUploadPreset = section["UploadPreset"] ?? "phongtro_unsigned";
            _listingUploadPreset = section["ListingUploadPreset"] ?? _defaultUploadPreset;
            _avatarUploadPreset = section["AvatarUploadPreset"] ?? _defaultUploadPreset;
            _chatUploadPreset = section["ChatUploadPreset"] ?? _defaultUploadPreset;
        }

        public string GetUploadUrl() => $"https://api.cloudinary.com/v1_1/{_cloudName}/auto/upload";

        public string GetUnsignedUploadPreset(string category)
        {
            return (category ?? string.Empty).Trim().ToLowerInvariant() switch
            {
                "listing" => _listingUploadPreset,
                "avatar" => _avatarUploadPreset,
                "chat" => _chatUploadPreset,
                _ => _defaultUploadPreset
            };
        }

        public string GetDownloadUrl(string publicId)
        {
            var safePublicId = publicId.TrimStart('/');
            return $"https://res.cloudinary.com/{_cloudName}/image/upload/{safePublicId}";
        }

        public async Task DeleteFileAsync(string publicId)
        {
            if (string.IsNullOrWhiteSpace(publicId))
            {
                return;
            }

            var timestamp = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
            var normalizedPublicId = publicId.Trim();
            var toSign = $"public_id={normalizedPublicId}&timestamp={timestamp}{_apiSecret}";
            var signature = ComputeSha1(toSign);

            using var httpClient = new HttpClient();
            using var form = new MultipartFormDataContent
            {
                { new StringContent(normalizedPublicId), "public_id" },
                { new StringContent(_apiKey), "api_key" },
                { new StringContent(timestamp.ToString()), "timestamp" },
                { new StringContent(signature), "signature" }
            };

            var endpoint = $"https://api.cloudinary.com/v1_1/{_cloudName}/image/destroy";
            var response = await httpClient.PostAsync(endpoint, form);

            if (!response.IsSuccessStatusCode)
            {
                var body = await response.Content.ReadAsStringAsync();
                throw new InvalidOperationException($"Xóa file Cloudinary thất bại. Status={(int)response.StatusCode}, Body={body}");
            }
        }

        private static string ComputeSha1(string input)
        {
            using var sha1 = SHA1.Create();
            var bytes = sha1.ComputeHash(Encoding.UTF8.GetBytes(input));
            return string.Concat(bytes.Select(b => b.ToString("x2")));
        }
    }
}
