using Backend_API.Models.DTOs.Users;
using Backend_API.Models.Entities;
using Backend_API.Services.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Backend_API.Services.Implementations
{
    public class PreferenceService : IPreferenceService
    {
        private readonly PhongTroDbContext _context;

        public PreferenceService(PhongTroDbContext context)
        {
            _context = context;
        }

        public async Task<UserPreferenceDto> SavePreferencesAsync(long userId, UserPreferenceDto dto)
        {
            var existingPref = await _context.UserPreferences
                .Include(p => p.UserPreferenceAmenities)
                .Include(p => p.UserPreferenceRoomTypes)
                .FirstOrDefaultAsync(p => p.UserId == userId);

            if (existingPref == null)
            {
                // Create new
                existingPref = new UserPreference
                {
                    UserId = userId,
                    CreatedAt = DateTime.UtcNow
                };
                await _context.UserPreferences.AddAsync(existingPref);
            }

            // Update scalar fields
            existingPref.PreferredArea = dto.PreferredArea;
            existingPref.MinPrice = dto.MinPrice;
            existingPref.MaxPrice = dto.MaxPrice;
            existingPref.AllowPet = dto.AllowPet;
            existingPref.Latitude = dto.Latitude;
            existingPref.Longitude = dto.Longitude;
            existingPref.SearchRadiusKm = dto.SearchRadiusKm;
            existingPref.OnboardingDone = dto.OnboardingDone ?? existingPref.OnboardingDone;
            existingPref.UpdatedAt = DateTime.UtcNow;

            // Update Amenities list
            _context.UserPreferenceAmenities.RemoveRange(existingPref.UserPreferenceAmenities);
            if (dto.AmenityIds != null && dto.AmenityIds.Count > 0)
            {
                foreach (var aId in dto.AmenityIds)
                {
                    existingPref.UserPreferenceAmenities.Add(new UserPreferenceAmenity
                    {
                        AmenityId = aId
                    });
                }
            }

            // Update Room Types list
            _context.UserPreferenceRoomTypes.RemoveRange(existingPref.UserPreferenceRoomTypes);
            if (dto.RoomTypeIds != null && dto.RoomTypeIds.Count > 0)
            {
                foreach (var tId in dto.RoomTypeIds)
                {
                    existingPref.UserPreferenceRoomTypes.Add(new UserPreferenceRoomType
                    {
                        TypeId = tId
                    });
                }
            }

            await _context.SaveChangesAsync();
            
            // Re-fetch to return complete DTO
            return await GetPreferencesAsync(userId) ?? throw new Exception("Error saving preferences.");
        }

        public async Task<UserPreferenceDto?> GetPreferencesAsync(long userId)
        {
            var pref = await _context.UserPreferences
                .Include(p => p.UserPreferenceAmenities)
                .Include(p => p.UserPreferenceRoomTypes)
                .FirstOrDefaultAsync(p => p.UserId == userId);

            if (pref == null) return null;

            return new UserPreferenceDto
            {
                PrefId = pref.PrefId,
                UserId = pref.UserId,
                PreferredArea = pref.PreferredArea,
                MinPrice = pref.MinPrice,
                MaxPrice = pref.MaxPrice,
                AllowPet = pref.AllowPet,
                Latitude = pref.Latitude,
                Longitude = pref.Longitude,
                SearchRadiusKm = pref.SearchRadiusKm,
                OnboardingDone = pref.OnboardingDone,
                AmenityIds = pref.UserPreferenceAmenities.Select(a => a.AmenityId).ToList(),
                RoomTypeIds = pref.UserPreferenceRoomTypes.Select(t => t.TypeId).ToList()
            };
        }
    }
}
