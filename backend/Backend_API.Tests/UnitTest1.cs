using Backend_API.Helpers;
using Backend_API.Models.Entities;
using Microsoft.Extensions.Configuration;
using Xunit;

namespace Backend_API.Tests
{
    public class AuthHelpersTests
    {
        [Fact]
        public void PasswordHasher_ShouldHashAndVerifyPassword()
        {
            // Arrange
            string originalPassword = "MySecurePassword123!";

            // Act
            string hash = PasswordHasher.Hash(originalPassword);
            bool isCorrect = PasswordHasher.Verify(originalPassword, hash);
            bool isIncorrect = PasswordHasher.Verify("WrongPassword", hash);

            // Assert
            Assert.NotNull(hash);
            Assert.NotEqual(originalPassword, hash);
            Assert.True(isCorrect);
            Assert.False(isIncorrect);
        }

        [Fact]
        public void JwtTokenHelper_ShouldGenerateAndValidateToken()
        {
            // Arrange
            var inMemorySettings = new Dictionary<string, string>
            {
                {"JwtSettings:SecretKey", "PhongTroApp_SuperSecretKey_2026_MustBe32CharsOrMore!"},
                {"JwtSettings:Issuer", "PhongTroAPI"},
                {"JwtSettings:Audience", "PhongTroApp"},
                {"JwtSettings:ExpireHours", "24"}
            };

            IConfiguration configuration = new ConfigurationBuilder()
                .AddInMemoryCollection(inMemorySettings!)
                .Build();

            var helper = new JwtTokenHelper(configuration);
            var user = new User
            {
                UserId = 1,
                Email = "test@example.com",
                RoleId = 2
            };

            // Act
            string token = helper.GenerateToken(user);
            var principal = helper.ValidateToken(token);

            // Assert
            Assert.False(string.IsNullOrEmpty(token));
            Assert.NotNull(principal);
            Assert.Equal("1", principal.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value);
            Assert.Equal("test@example.com", principal.FindFirst(System.Security.Claims.ClaimTypes.Email)?.Value);
            Assert.Equal("2", principal.FindFirst("RoleId")?.Value);
        }
        [Fact]
        public async Task FirebaseHelper_VerifyToken_WithFakeToken_ThrowsException()
        {
            // Arrange
            // Ensure Firebase is initialized with the dummy file created
            string currentDir = Directory.GetCurrentDirectory();
            string projectParentDir = Directory.GetParent(currentDir)?.Parent?.Parent?.FullName ?? currentDir;
            // The file is typically in backend/Backend_API/Backend_API/firebase-adminsdk.json
            string dummyPath = Path.Combine(projectParentDir, "..", "Backend_API", "Backend_API", "firebase-adminsdk.json");
            
            if (File.Exists(dummyPath))
            {
                // Act & Assert
                await Assert.ThrowsAnyAsync<Exception>(async () =>
                {
                    FirebaseHelper.InitializeApp(dummyPath, "your-firebase-project-id");
                    var helper = new FirebaseHelper();
                    await helper.VerifyIdToken("fake-token");
                });
            }
        }
    }
}
