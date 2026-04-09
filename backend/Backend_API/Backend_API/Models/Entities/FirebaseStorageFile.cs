using System;
using System.Collections.Generic;

namespace Backend_API.Models.Entities;

public partial class FirebaseStorageFile
{
    public long FileId { get; set; }

    public long UserId { get; set; }

    public string StoragePath { get; set; } = null!;

    public string DownloadUrl { get; set; } = null!;

    public string FileType { get; set; } = null!;

    public int? FileSizeKb { get; set; }

    public string? MimeType { get; set; }

    public string? RefType { get; set; }

    public long? RefId { get; set; }

    public bool? IsActive { get; set; }

    public DateTime? CreatedAt { get; set; }

    public DateTime? DeletedAt { get; set; }

    public virtual User User { get; set; } = null!;
}
