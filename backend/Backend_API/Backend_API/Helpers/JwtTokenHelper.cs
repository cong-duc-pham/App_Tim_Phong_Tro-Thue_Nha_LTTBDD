using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Backend_API.Models.Entities;
using Microsoft.Extensions.Configuration;
using Microsoft.IdentityModel.Tokens;

namespace Backend_API.Helpers
{
    public class JwtTokenHelper
    {
        private readonly IConfiguration _config;

        public JwtTokenHelper(IConfiguration config)
        {
            _config = config;
        }

        public string GenerateToken(User user)
        {
            var jwtConfig = _config.GetSection("JwtSettings");
            var keyStr = jwtConfig["SecretKey"];
            if (string.IsNullOrEmpty(keyStr))
            {
                throw new ArgumentNullException("JwtSettings:SecretKey is missing from configuration.");
            }

            var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(keyStr));
            var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);
            
            var claims = new List<Claim>
            {
                new Claim(JwtRegisteredClaimNames.Sub, user.UserId.ToString()),
                new Claim(ClaimTypes.NameIdentifier, user.UserId.ToString()),
                new Claim(JwtRegisteredClaimNames.Email, user.Email ?? ""),
                new Claim(ClaimTypes.Role, user.Role?.RoleName ?? "Tenant"),
                new Claim("RoleId", user.RoleId.ToString())
            };

            var expireHours = double.TryParse(jwtConfig["ExpireHours"], out double h) ? h : 24;

            var token = new JwtSecurityToken(
                issuer: jwtConfig["Issuer"],
                audience: jwtConfig["Audience"],
                claims: claims,
                expires: DateTime.UtcNow.AddHours(expireHours),
                signingCredentials: creds
            );

            return new JwtSecurityTokenHandler().WriteToken(token);
        }

        public ClaimsPrincipal? ValidateToken(string token)
        {
            var jwtConfig = _config.GetSection("JwtSettings");
            var keyStr = jwtConfig["SecretKey"];
            if (string.IsNullOrEmpty(keyStr))
            {
                return null;
            }

            var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(keyStr));
            var tokenHandler = new JwtSecurityTokenHandler();

            try
            {
                var principal = tokenHandler.ValidateToken(token, new TokenValidationParameters
                {
                    ValidateIssuerSigningKey = true,
                    IssuerSigningKey = key,
                    ValidateIssuer = true,
                    ValidIssuer = jwtConfig["Issuer"],
                    ValidateAudience = true,
                    ValidAudience = jwtConfig["Audience"],
                    ValidateLifetime = true,
                    ClockSkew = TimeSpan.Zero
                }, out SecurityToken validatedToken);

                return principal;
            }
            catch
            {
                // Token is either invalid or expired
                return null;
            }
        }
    }
}
