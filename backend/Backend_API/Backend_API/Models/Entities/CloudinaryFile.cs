using System;

namespace Backend_API.Models.Entities;

public partial class CloudinaryFile
{
    public long FileId { get; set; }

    public long UserId { get; set; }

    public string PublicId { get; set; } = null!;

    public string SecureUrl { get; set; } = null!;

    public string? DeliveryUrl { get; set; }

    public string ResourceType { get; set; } = null!;

    public string? Format { get; set; }

    public int? Width { get; set; }

    public int? Height { get; set; }

    public int? DurationSec { get; set; }

    public int? FileSizeKb { get; set; }

    public string? Folder { get; set; }

    public string? RefType { get; set; }

    public long? RefId { get; set; }

    public bool? IsActive { get; set; }

    public string? UploadStatus { get; set; }

    public DateTime? CreatedAt { get; set; }

    public DateTime? DeletedAt { get; set; }

    public virtual User User { get; set; } = null!;
}
