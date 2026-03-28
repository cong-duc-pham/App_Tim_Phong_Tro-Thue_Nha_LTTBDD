namespace Backend_API.Models.Entities;

public class Province
{
    public int ProvinceId { get; set; }
    public string ProvinceName { get; set; } = string.Empty;
    public string? ProvinceCode { get; set; }
    public ICollection<District> Districts { get; set; } = new List<District>();
}

public class District
{
    public int DistrictId { get; set; }
    public int ProvinceId { get; set; }
    public string DistrictName { get; set; } = string.Empty;
    public string? DistrictCode { get; set; }
    public Province Province { get; set; } = null!;
    public ICollection<Ward> Wards { get; set; } = new List<Ward>();
}

public class Ward
{
    public int WardId { get; set; }
    public int DistrictId { get; set; }
    public string WardName { get; set; } = string.Empty;
    public string? WardCode { get; set; }
    public District District { get; set; } = null!;
}
