using FirebaseAdmin.Messaging;
using Microsoft.EntityFrameworkCore;
using Backend_API.Models.Entities;

namespace Backend_API.Helpers
{
    public class FirebaseMessagingHelper
    {
        private readonly IServiceScopeFactory _scopeFactory;

        public FirebaseMessagingHelper(IServiceScopeFactory scopeFactory)
        {
            _scopeFactory = scopeFactory;
        }

        /// <summary>
        /// Gửi thông báo đến 1 device cụ thể thông qua FCM Token.
        /// </summary>
        public async Task<bool> SendToDeviceAsync(string fcmToken, string title, string body, Dictionary<string, string>? data = null)
        {
            try
            {
                var message = new FirebaseAdmin.Messaging.Message()
                {
                    Token = fcmToken,
                    Notification = new FirebaseAdmin.Messaging.Notification()
                    {
                        Title = title,
                        Body = body
                    },
                    Data = data ?? new Dictionary<string, string>()
                };

                // Trả về string là message id (dạng "projects/myproject-b5ae1/messages/0:1500415314455276%31bd1c9631bd1c96")
                string response = await FirebaseMessaging.DefaultInstance.SendAsync(message);
                return true;
            }
            catch (FirebaseMessagingException ex)
            {
                // Nếu token không còn hợp lệ (user gỡ app, token hết hạn...)
                if (ex.MessagingErrorCode == MessagingErrorCode.Unregistered ||
                    ex.MessagingErrorCode == MessagingErrorCode.InvalidArgument ||
                    ex.MessagingErrorCode == MessagingErrorCode.SenderIdMismatch)
                {
                    await InvalidateTokenAsync(fcmToken);
                }
                
                Console.WriteLine($"[FCM Error] Gửi thông báo thất bại: {ex.Message}");
                return false;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[FCM Error] Lỗi nghiêm trọng gửi thông báo: {ex.Message}");
                return false;
            }
        }

        /// <summary>
        /// Gửi thông báo đến danh sách nhiều thiết bị cùng lúc (Multicast).
        /// Hỗ trợ tối đa 500 tokens mỗi lần gửi theo giới hạn Firebase.
        /// </summary>
        public async Task<bool> SendToMultipleAsync(List<string> fcmTokens, string title, string body, Dictionary<string, string>? data = null)
        {
            if (fcmTokens == null || fcmTokens.Count == 0) return false;

            try
            {
                // Firebase MulticastMessages support max 500 tokens per batch
                var message = new MulticastMessage()
                {
                    Tokens = fcmTokens.Take(500).ToList(),
                    Notification = new FirebaseAdmin.Messaging.Notification()
                    {
                        Title = title,
                        Body = body
                    },
                    Data = data ?? new Dictionary<string, string>()
                };

                var response = await FirebaseMessaging.DefaultInstance.SendMulticastAsync(message);
                
                // Nếu có token bị lỗi trong batch (ví dụ: Unregistered) → Invalidate chúng
                if (response.FailureCount > 0)
                {
                    var failedTokens = new List<string>();
                    for (int i = 0; i < response.Responses.Count; i++)
                    {
                        var res = response.Responses[i];
                        if (!res.IsSuccess)
                        {
                            var errorCode = res.Exception?.MessagingErrorCode;
                            if (errorCode == MessagingErrorCode.Unregistered ||
                                errorCode == MessagingErrorCode.InvalidArgument ||
                                errorCode == MessagingErrorCode.SenderIdMismatch)
                            {
                                failedTokens.Add(fcmTokens[i]);
                            }
                        }
                    }

                    if (failedTokens.Count > 0)
                    {
                        foreach (var token in failedTokens)
                        {
                            await InvalidateTokenAsync(token);
                        }
                    }
                }

                return response.SuccessCount > 0;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[FCM Multicast Error] Lỗi gửi nhiều tb: {ex.Message}");
                return false;
            }
        }

        /// <summary>
        /// Gửi thông báo broadcast cho toàn bộ users theo dõi một Topic (ví dụ: "system", "promotions")
        /// </summary>
        public async Task<bool> SendTopicAsync(string topic, string title, string body, Dictionary<string, string>? data = null)
        {
            try
            {
                var message = new FirebaseAdmin.Messaging.Message()
                {
                    Topic = topic,
                    Notification = new FirebaseAdmin.Messaging.Notification()
                    {
                        Title = title,
                        Body = body
                    },
                    Data = data ?? new Dictionary<string, string>()
                };

                await FirebaseMessaging.DefaultInstance.SendAsync(message);
                return true;
            }
            catch (Exception ex)
            {
                 Console.WriteLine($"[FCM Topic Error] Lỗi gửi theo chủ đề: {ex.Message}");
                 return false;
            }
        }

        /// <summary>
        /// Gọi Stored Procedure xóa / vô hiệu hóa token trong database.
        /// Sử dụng scope riêng để không ảnh hưởng đến transaction hiện tại.
        /// </summary>
        private async Task InvalidateTokenAsync(string fcmToken)
        {
            try
            {
                using var scope = _scopeFactory.CreateScope();
                var dbContext = scope.ServiceProvider.GetRequiredService<PhongTroDbContext>();

                // Dùng phương thức ExecuteSqlRawAsync thay thế nếu db dùng sql parameter
                // @p0 để truyền giá trị tham số sql 1 cách an toàn.
                await dbContext.Database.ExecuteSqlRawAsync("EXEC sp_InvalidateFcmToken @p0", fcmToken);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[FCM DB Error] Lỗi vô hiệu hoá token: {ex.Message}");
            }
        }
    }
}
