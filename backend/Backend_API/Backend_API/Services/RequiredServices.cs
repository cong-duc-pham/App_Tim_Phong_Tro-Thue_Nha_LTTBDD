using MailKit.Net.Smtp;
using MailKit.Security;
using MimeKit;

namespace Backend_API.Services
{
    public interface IJwtService { }

    public class JwtService : IJwtService { }

    public interface IEmailService
    {
        Task SendPasswordResetOtpAsync(string toEmail, string otpCode);
    }

    public class EmailService : IEmailService
    {
        private readonly IConfiguration _configuration;
        private readonly ILogger<EmailService> _logger;

        public EmailService(IConfiguration configuration, ILogger<EmailService> logger)
        {
            _configuration = configuration;
            _logger = logger;
        }

        public async Task SendPasswordResetOtpAsync(string toEmail, string otpCode)
        {
            var section = _configuration.GetSection("Email");
            var host = section["SmtpHost"];
            var senderEmail = section["SenderEmail"];
            var senderPassword = section["SenderPassword"];
            var senderName = section["SenderName"] ?? "Swings House";
            var port = int.TryParse(section["SmtpPort"], out var parsedPort) ? parsedPort : 587;

            if (string.IsNullOrWhiteSpace(host)
                || string.IsNullOrWhiteSpace(senderEmail)
                || string.IsNullOrWhiteSpace(senderPassword)
                || senderEmail.Contains("your-email", StringComparison.OrdinalIgnoreCase)
                || senderPassword.Contains("your-app-password", StringComparison.OrdinalIgnoreCase))
            {
                _logger.LogWarning("SMTP is not configured. Password reset OTP for {Email}: {OtpCode}", toEmail, otpCode);
                Console.WriteLine($"[DEV OTP] {toEmail}: {otpCode}");
                return;
            }

            var message = new MimeMessage();
            message.From.Add(new MailboxAddress(senderName, senderEmail));
            message.To.Add(MailboxAddress.Parse(toEmail));
            message.Subject = "Ma OTP dat lai mat khau Swings House";
            message.Body = new TextPart("html")
            {
                Text = $@"
                    <div style=""font-family:Arial,sans-serif;line-height:1.6;color:#111827"">
                        <h2>Swings House</h2>
                        <p>Ma OTP dat lai mat khau cua ban la:</p>
                        <div style=""font-size:28px;font-weight:700;letter-spacing:6px;color:#0d6efd"">{otpCode}</div>
                        <p>Ma co hieu luc trong 10 phut. Neu ban khong yeu cau, hay bo qua email nay.</p>
                    </div>"
            };

            using var smtp = new SmtpClient();
            await smtp.ConnectAsync(host, port, SecureSocketOptions.StartTls);
            await smtp.AuthenticateAsync(senderEmail, senderPassword);
            await smtp.SendAsync(message);
            await smtp.DisconnectAsync(true);
        }
    }
}
