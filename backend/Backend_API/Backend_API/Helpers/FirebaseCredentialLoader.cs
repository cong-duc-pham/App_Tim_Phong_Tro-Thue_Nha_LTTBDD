using System.Text;
using System.Text.Json.Nodes;
using Google.Apis.Auth.OAuth2;

namespace Backend_API.Helpers
{
    public static class FirebaseCredentialLoader
    {
        public static GoogleCredential LoadGoogleCredential(string credentialPathOrContent)
        {
            if (string.IsNullOrWhiteSpace(credentialPathOrContent))
            {
                throw new InvalidOperationException("Firebase credential chưa được cấu hình.");
            }

            var trimmed = credentialPathOrContent.Trim();
            if (trimmed.StartsWith("{"))
            {
                return CreateCredentialFromRaw(trimmed);
            }

            var resolvedPath = ResolvePath(trimmed);
            if (!File.Exists(resolvedPath))
            {
                throw new FileNotFoundException(
                    $"Không tìm thấy Firebase credential file tại: {resolvedPath}");
            }

            var rawCredential = File.ReadAllText(resolvedPath);
            return CreateCredentialFromRaw(rawCredential);
        }

        private static GoogleCredential CreateCredentialFromRaw(string raw)
        {
            var candidate = raw.Trim();

            JsonNode? node;
            try
            {
                node = JsonNode.Parse(candidate);
            }
            catch (Exception ex)
            {
                throw new InvalidOperationException("Firebase credential không phải JSON hợp lệ.", ex);
            }

            if (node is not JsonObject obj)
            {
                throw new InvalidOperationException("Firebase credential JSON không đúng định dạng object.");
            }

            var privateKey = obj["private_key"]?.GetValue<string>();
            if (!string.IsNullOrEmpty(privateKey))
            {
                obj["private_key"] = privateKey
                    .Replace("\\r\\n", "\n")
                    .Replace("\\n", "\n")
                    .Replace("\r\n", "\n");
            }
            else
            {
                throw new InvalidOperationException("Thiếu trường private_key trong Firebase service account JSON.");
            }

            var normalizedPrivateKey = obj["private_key"]?.GetValue<string>() ?? string.Empty;
            var cleanedPrivateKey = normalizedPrivateKey.Replace("\n", string.Empty).Trim();
            if (!normalizedPrivateKey.Contains("BEGIN PRIVATE KEY", StringComparison.Ordinal) ||
                !normalizedPrivateKey.Contains("END PRIVATE KEY", StringComparison.Ordinal) ||
                cleanedPrivateKey.Contains("...", StringComparison.Ordinal) ||
                cleanedPrivateKey.EndsWith("...", StringComparison.Ordinal))
            {
                throw new InvalidOperationException(
                    "private_key trong Firebase service account JSON không hợp lệ. Hãy dùng file JSON gốc tải từ Firebase Console.");
            }

            var normalizedJson = obj.ToJsonString();
            using var stream = new MemoryStream(Encoding.UTF8.GetBytes(normalizedJson));
            try
            {
                return GoogleCredential.FromStream(stream);
            }
            catch (FormatException ex)
            {
                throw new InvalidOperationException(
                    "Firebase service account không hợp lệ (private_key sai định dạng). Vui lòng dùng file JSON service account chuẩn tải từ Firebase Console.",
                    ex);
            }
        }

        private static string ResolvePath(string path)
        {
            if (Path.IsPathRooted(path))
            {
                return path;
            }

            var baseDirCandidate = Path.Combine(AppContext.BaseDirectory, path);
            if (File.Exists(baseDirCandidate))
            {
                return baseDirCandidate;
            }

            return Path.GetFullPath(path);
        }
    }
}
