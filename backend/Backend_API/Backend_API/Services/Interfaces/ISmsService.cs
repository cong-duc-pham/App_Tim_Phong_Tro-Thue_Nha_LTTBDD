using System.Threading.Tasks;

namespace Backend_API.Services.Interfaces
{
    public interface ISmsService
    {
        Task<bool> SendSmsAsync(string phone, string message);
    }
}
