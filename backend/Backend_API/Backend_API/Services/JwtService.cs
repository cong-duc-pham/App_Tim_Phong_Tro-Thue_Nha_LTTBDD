using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Backend_API.Models.Entities;
using Microsoft.IdentityModel.Tokens;

namespace Backend_API.Services;

public interface IJwtService
{
    string GenerateToken(User user);
}

public class JwtService : IJwtService
{
    private readonly IConfiguration _config;

    public JwtService(IConfiguration config) => _config = config;

    public string GenerateToken(User user)
    {
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_config["Jwt:Key"]!));
        var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var claims = new[]
        {
            new Claim(JwtRegisteredClaimNames.Sub, user.UserId.ToString()),
            new Claim(JwtRegisteredClaimNames.Email, user.Email ?? ""),
            new Claim(ClaimTypes.Role, user.Role?.RoleName ?? "tenant"),
            new Claim("userId", user.UserId.ToString()),
            new Claim("roleId", user.RoleId.ToString())
        };

        var token = new JwtSecurityToken(
            issuer: _config["Jwt:Issuer"],
            audience: _config["Jwt:Audience"],
            claims: claims,
            expires: DateTime.UtcNow.AddHours(int.Parse(_config["Jwt:ExpireHours"]!)),
            signingCredentials: creds
        );

        return new JwtSecurityTokenHandler().WriteToken(token);
    }
}
