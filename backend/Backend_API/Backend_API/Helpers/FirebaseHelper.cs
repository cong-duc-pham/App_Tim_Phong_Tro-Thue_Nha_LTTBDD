using FirebaseAdmin;
using FirebaseAdmin.Auth;

namespace Backend_API.Helpers
{
    public class FirebaseHelper
    {
        public static void InitializeApp(string credentialPath, string projectId)
        {
            if (FirebaseApp.DefaultInstance == null)
            {
                if (!string.IsNullOrWhiteSpace(credentialPath))
                {
                    FirebaseApp.Create(new AppOptions
                    {
                        Credential = FirebaseCredentialLoader.LoadGoogleCredential(credentialPath),
                        ProjectId = projectId
                    });
                }
            }
        }

        public async Task<(string uid, string email, string name, string picture)> VerifyIdToken(string firebaseToken)
        {
            if (string.IsNullOrEmpty(firebaseToken))
                throw new ArgumentException("Token rỗng", nameof(firebaseToken));

            var defaultAuth = FirebaseAuth.DefaultInstance;
            if (defaultAuth == null)
            {
                throw new InvalidOperationException("FirebaseApp chưa được Initialize.");
            }

            FirebaseToken decodedToken = await defaultAuth.VerifyIdTokenAsync(firebaseToken);
            
            string uid = decodedToken.Uid;
            
            decodedToken.Claims.TryGetValue("email", out object? emailObj);
            string email = emailObj?.ToString() ?? string.Empty;

            decodedToken.Claims.TryGetValue("name", out object? nameObj);
            string name = nameObj?.ToString() ?? string.Empty;

            decodedToken.Claims.TryGetValue("picture", out object? picObj);
            string picture = picObj?.ToString() ?? string.Empty;

            return (uid, email, name, picture);
        }
    }
}
