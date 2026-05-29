using System.Security.Claims;
using Backend_API.Helpers;
using Backend_API.Models.DTOs.Storage;
using Backend_API.Models.Entities;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Backend_API.Controllers.API
{
    [ApiController]
    [Route("api/storage")]
    [Authorize]
    [Tags("Storage")]
    public class StorageApiController : ControllerBase
    {
        private static readonly HashSet<string> AllowedImageExtensions = new(StringComparer.OrdinalIgnoreCase)
        {
            ".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp"
        };

        private readonly PhongTroDbContext _context;
        private readonly CloudinaryStorageHelper _storageHelper;

        public StorageApiController(PhongTroDbContext context, CloudinaryStorageHelper storageHelper)
        {
            _context = context;
            _storageHelper = storageHelper;
        }

        [HttpPost("listings/{listingId:long}/images")]
        [RequestSizeLimit(10 * 1024 * 1024)]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(object), StatusCodes.Status400BadRequest)]
        [ProducesResponseType(typeof(object), StatusCodes.Status401Unauthorized)]
        [ProducesResponseType(typeof(object), StatusCodes.Status403Forbidden)]
        [ProducesResponseType(typeof(object), StatusCodes.Status404NotFound)]
        public async Task<IActionResult> UploadListingImage(long listingId, IFormFile file, [FromForm] string? uploadType)
        {
            var userId = GetCurrentUserId();
            if (userId == null)
            {
                return Unauthorized(new { success = false, message = "Chua dang nhap." });
            }

            var listing = await _context.Listings
                .AsNoTracking()
                .FirstOrDefaultAsync(l => l.ListingId == listingId);

            if (listing == null)
            {
                return NotFound(new { success = false, message = "Khong tim thay tin dang." });
            }

            if (listing.LandlordId != userId.Value)
            {
                return Forbid();
            }

            if (file == null || file.Length == 0)
            {
                return BadRequest(new { success = false, message = "Vui long chon anh." });
            }

            if (file.Length > 10 * 1024 * 1024)
            {
                return BadRequest(new { success = false, message = "Anh khong duoc vuot qua 10 MB." });
            }

            if (!TryResolveImageExtension(file.FileName, file.ContentType, out var extension))
            {
                return BadRequest(new { success = false, message = "Dinh dang anh khong hop le." });
            }

            var safeUploadType = (uploadType ?? "gallery").Trim().ToLowerInvariant();
            if (safeUploadType != "cover" && safeUploadType != "gallery")
            {
                safeUploadType = "gallery";
            }

            var fileName = safeUploadType == "cover"
                ? $"cover{extension}"
                : $"{Guid.NewGuid():N}{extension}";

            var webRoot = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot");
            var relativeDirectory = Path.Combine("uploads", "listings", listingId.ToString());
            var physicalDirectory = Path.Combine(webRoot, relativeDirectory);
            Directory.CreateDirectory(physicalDirectory);

            var physicalPath = Path.Combine(physicalDirectory, fileName);
            await using (var stream = System.IO.File.Create(physicalPath))
            {
                await file.CopyToAsync(stream);
            }

            var relativeUrl = $"/uploads/listings/{listingId}/{fileName}";
            var absoluteUrl = $"{Request.Scheme}://{Request.Host}{relativeUrl}";

            return Ok(new
            {
                success = true,
                data = new
                {
                    url = absoluteUrl,
                    relativeUrl,
                    fileName,
                    uploadType = safeUploadType
                }
            });
        }

        [HttpPost("listings/{listingId:long}/signed-upload-url")]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(object), StatusCodes.Status400BadRequest)]
        [ProducesResponseType(typeof(object), StatusCodes.Status401Unauthorized)]
        [ProducesResponseType(typeof(object), StatusCodes.Status403Forbidden)]
        [ProducesResponseType(typeof(object), StatusCodes.Status404NotFound)]
        public async Task<IActionResult> GetListingUploadUrl(long listingId, [FromBody] GenerateSignedUploadUrlRequestDto request)
        {
            var userId = GetCurrentUserId();
            if (userId == null)
            {
                return Unauthorized(new { success = false, message = "Chưa đăng nhập." });
            }

            var listing = await _context.Listings
                .AsNoTracking()
                .FirstOrDefaultAsync(l => l.ListingId == listingId);

            if (listing == null)
            {
                return NotFound(new { success = false, message = "Không tìm thấy tin đăng." });
            }

            if (listing.LandlordId != userId.Value)
            {
                return Forbid();
            }

            if (!TryResolveImageExtension(request.FileName, request.ContentType, out var extension))
            {
                return BadRequest(new { success = false, message = "Định dạng ảnh không hợp lệ." });
            }

            var uploadType = (request.UploadType ?? "gallery").Trim().ToLowerInvariant();
            if (uploadType != "cover" && uploadType != "gallery")
            {
                return BadRequest(new { success = false, message = "uploadType chỉ hỗ trợ: cover hoặc gallery." });
            }

            var objectName = uploadType == "cover"
                ? $"cover{extension}"
                : $"gallery/{Guid.NewGuid():N}{extension}";

            var storagePath = $"listings/{listingId}/{objectName}";
            var uploadPreset = _storageHelper.GetUnsignedUploadPreset("listing");
            var uploadUrl = _storageHelper.GetUploadUrl();
            var downloadUrl = _storageHelper.GetDownloadUrl(storagePath);

            return Ok(new
            {
                success = true,
                data = new SignedUploadUrlResponseDto
                {
                    UploadUrl = uploadUrl,
                    DownloadUrl = downloadUrl,
                    StoragePath = storagePath,
                    MaxFileSizeMb = 10,
                    RequiredContentTypePrefix = "image/",
                    UploadPreset = uploadPreset,
                    PublicId = storagePath
                }
            });
        }

        [HttpPost("avatars/signed-upload-url")]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(object), StatusCodes.Status400BadRequest)]
        [ProducesResponseType(typeof(object), StatusCodes.Status401Unauthorized)]
        public IActionResult GetAvatarUploadUrl([FromBody] GenerateSignedUploadUrlRequestDto request)
        {
            var userId = GetCurrentUserId();
            if (userId == null)
            {
                return Unauthorized(new { success = false, message = "Chưa đăng nhập." });
            }

            if (!TryResolveImageExtension(request.FileName, request.ContentType, out var extension))
            {
                return BadRequest(new { success = false, message = "Định dạng ảnh không hợp lệ." });
            }

            var storagePath = $"avatars/{userId}/{Guid.NewGuid():N}{extension}";
            var uploadPreset = _storageHelper.GetUnsignedUploadPreset("avatar");
            var uploadUrl = _storageHelper.GetUploadUrl();
            var downloadUrl = _storageHelper.GetDownloadUrl(storagePath);

            return Ok(new
            {
                success = true,
                data = new SignedUploadUrlResponseDto
                {
                    UploadUrl = uploadUrl,
                    DownloadUrl = downloadUrl,
                    StoragePath = storagePath,
                    MaxFileSizeMb = 5,
                    RequiredContentTypePrefix = "image/",
                    UploadPreset = uploadPreset,
                    PublicId = storagePath
                }
            });
        }

        [HttpPost("chat/{conversationId:long}/signed-upload-url")]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(object), StatusCodes.Status400BadRequest)]
        [ProducesResponseType(typeof(object), StatusCodes.Status401Unauthorized)]
        [ProducesResponseType(typeof(object), StatusCodes.Status403Forbidden)]
        [ProducesResponseType(typeof(object), StatusCodes.Status404NotFound)]
        public async Task<IActionResult> GetChatUploadUrl(long conversationId, [FromBody] GenerateSignedUploadUrlRequestDto request)
        {
            var userId = GetCurrentUserId();
            if (userId == null)
            {
                return Unauthorized(new { success = false, message = "Chưa đăng nhập." });
            }

            var conversation = await _context.Conversations
                .AsNoTracking()
                .FirstOrDefaultAsync(c => c.ConvId == conversationId);

            if (conversation == null)
            {
                return NotFound(new { success = false, message = "Không tìm thấy cuộc hội thoại." });
            }

            var isParticipant = conversation.TenantId == userId.Value || conversation.LandlordId == userId.Value;
            if (!isParticipant)
            {
                return Forbid();
            }

            var safeExtension = GetSafeExtension(request.FileName);
            if (string.IsNullOrWhiteSpace(safeExtension))
            {
                safeExtension = ".bin";
            }

            var storagePath = $"chat/{conversationId}/{Guid.NewGuid():N}{safeExtension}";
            var uploadPreset = _storageHelper.GetUnsignedUploadPreset("chat");
            var uploadUrl = _storageHelper.GetUploadUrl();
            var downloadUrl = _storageHelper.GetDownloadUrl(storagePath);

            return Ok(new
            {
                success = true,
                data = new SignedUploadUrlResponseDto
                {
                    UploadUrl = uploadUrl,
                    DownloadUrl = downloadUrl,
                    StoragePath = storagePath,
                    MaxFileSizeMb = 10,
                    RequiredContentTypePrefix = "*",
                    UploadPreset = uploadPreset,
                    PublicId = storagePath
                }
            });
        }

        private long? GetCurrentUserId()
        {
            var claim = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrWhiteSpace(claim) || !long.TryParse(claim, out var userId))
            {
                return null;
            }

            return userId;
        }

        private static string GetSafeExtension(string fileName)
        {
            var extension = Path.GetExtension(fileName)?.Trim();
            if (string.IsNullOrWhiteSpace(extension))
            {
                return string.Empty;
            }

            if (extension.Length > 10)
            {
                return string.Empty;
            }

            return extension.ToLowerInvariant();
        }

        private static bool TryResolveImageExtension(string fileName, string? contentType, out string extension)
        {
            extension = GetSafeExtension(fileName);

            if (!string.IsNullOrEmpty(extension) && AllowedImageExtensions.Contains(extension))
            {
                return true;
            }

            var mapped = MapImageExtensionFromContentType(contentType);
            if (!string.IsNullOrEmpty(mapped))
            {
                extension = mapped;
                return true;
            }

            return false;
        }

        private static string? MapImageExtensionFromContentType(string? contentType)
        {
            if (string.IsNullOrWhiteSpace(contentType))
            {
                return null;
            }

            return contentType.Trim().ToLowerInvariant() switch
            {
                "image/jpeg" => ".jpg",
                "image/png" => ".png",
                "image/webp" => ".webp",
                "image/gif" => ".gif",
                "image/bmp" => ".bmp",
                _ => null
            };
        }
    }
}
