using MailKit.Net.Smtp;
using MailKit.Security;
using MimeKit;

namespace Backend_API.Services;

public interface IEmailService
{
    Task SendOtpAsync(string toEmail, string otp, string purpose);
}

public class EmailService : IEmailService
{
    private readonly IConfiguration _config;

    public EmailService(IConfiguration config) => _config = config;

    public async Task SendOtpAsync(string toEmail, string otp, string purpose)
    {
        var subject = purpose switch
        {
            "register" => "Xác thực tài khoản Phòng Trọ App",
            "forgot_password" => "Đặt lại mật khẩu Phòng Trọ App",
            _ => "Mã OTP Phòng Trọ App"
        };

        var body = $"""
            <h2>Phòng Trọ App</h2>
            <p>Mã OTP của bạn là: <strong style="font-size:24px;color:#007bff">{otp}</strong></p>
            <p>Mã có hiệu lực trong <strong>5 phút</strong>. Không chia sẻ mã này với ai.</p>
            """;

        var message = new MimeMessage();
        message.From.Add(new MailboxAddress(_config["Email:SenderName"], _config["Email:SenderEmail"]));
        message.To.Add(MailboxAddress.Parse(toEmail));
        message.Subject = subject;
        message.Body = new TextPart("html") { Text = body };

        using var client = new SmtpClient();
        await client.ConnectAsync(_config["Email:SmtpHost"], int.Parse(_config["Email:SmtpPort"]!), SecureSocketOptions.StartTls);
        await client.AuthenticateAsync(_config["Email:SenderEmail"], _config["Email:SenderPassword"]);
        await client.SendAsync(message);
        await client.DisconnectAsync(true);
    }
}
