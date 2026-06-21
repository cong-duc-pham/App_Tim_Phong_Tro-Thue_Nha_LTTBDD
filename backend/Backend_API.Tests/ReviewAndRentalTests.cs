using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Backend_API.Models.DTOs.Notifications;
using Backend_API.Models.DTOs.Rentals;
using Backend_API.Models.DTOs.Reviews;
using Backend_API.Models.Entities;
using Backend_API.Services.Implementations;
using Backend_API.Services.Interfaces;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace Backend_API.Tests
{
    public class FakeNotificationService : INotificationService
    {
        public List<(long UserId, string Title, string Body, string Type)> SentNotifications { get; } = new();

        public Task<bool> CreateAndSendAsync(long userId, string title, string body, string notifType, long? refId = null, string? refType = null)
        {
            SentNotifications.Add((userId, title, body, notifType));
            return Task.FromResult(true);
        }

        public Task<List<NotificationDto>> GetNotificationsAsync(long userId) => Task.FromResult(new List<NotificationDto>());
        public Task MarkAsReadAsync(long notifId, long userId) => Task.CompletedTask;
        public Task<int> GetUnreadCountAsync(long userId) => Task.FromResult(0);
    }

    public class ReviewAndRentalTests
    {
        private sealed class FakeListingRealtimeNotifier : IListingRealtimeNotifier
        {
            public List<(long ListingId, string Action, string? StatusName)> Events { get; } = new();

            public Task NotifyListingsChangedAsync(long listingId, string action, string? statusName = null)
            {
                Events.Add((listingId, action, statusName));
                return Task.CompletedTask;
            }
        }

        private PhongTroDbContext GetDatabaseContext()
        {
            var options = new DbContextOptionsBuilder<PhongTroDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString())
                .Options;

            var context = new PhongTroDbContext(options);
            context.Database.EnsureCreated();
            return context;
        }

        private static Listing CreateListing(long landlordId) =>
            new()
            {
                ListingId = 10,
                LandlordId = landlordId,
                TypeId = 1,
                StatusId = 1,
                Title = "Phong Tro Dep",
                Price = 1000000,
                Area = 20,
                StreetAddress = "123 Le Loi"
            };

        private static List<ListingStatus> CreateListingStatuses() =>
            new()
            {
                new ListingStatus { StatusId = 1, StatusName = "active" },
                new ListingStatus { StatusId = 3, StatusName = "rented" },
            };

        [Fact]
        public async Task CreateQnaReview_ShouldSucceedWithoutRenterStatus()
        {
            var context = GetDatabaseContext();
            var fakeNotification = new FakeNotificationService();
            var reviewService = new ReviewService(context, fakeNotification);

            var landlord = new User { UserId = 1, FullName = "Landlord", Phone = "0123456789", Email = "landlord@test.com" };
            var tenant = new User { UserId = 2, FullName = "Tenant", Phone = "0987654321", Email = "tenant@test.com" };
            var listing = CreateListing(landlord.UserId);

            await context.Users.AddRangeAsync(landlord, tenant);
            await context.Listings.AddAsync(listing);
            await context.SaveChangesAsync();

            var dto = new ReviewCreateDto
            {
                Comment = "Toi muon hoi xem phong vao ngay mai duoc khong?",
                Type = "qna"
            };

            var result = await reviewService.CreateReviewAsync(tenant.UserId, listing.ListingId, dto);

            Assert.NotNull(result);
            Assert.Equal("qna", result.Type);
            Assert.Null(result.Rating);
            Assert.Equal("approved", result.Status);
            Assert.False(result.IsVerifiedTenant);
            Assert.Single(fakeNotification.SentNotifications);
        }

        [Fact]
        public async Task CreateReview_WithoutRenterStatus_ShouldThrowException()
        {
            var context = GetDatabaseContext();
            var fakeNotification = new FakeNotificationService();
            var reviewService = new ReviewService(context, fakeNotification);

            var landlord = new User { UserId = 1, FullName = "Landlord", Phone = "0123456789", Email = "landlord@test.com" };
            var tenant = new User { UserId = 2, FullName = "Tenant", Phone = "0987654321", Email = "tenant@test.com" };
            var listing = CreateListing(landlord.UserId);

            await context.Users.AddRangeAsync(landlord, tenant);
            await context.Listings.AddAsync(listing);
            await context.SaveChangesAsync();

            var dto = new ReviewCreateDto
            {
                Comment = "Phong rat dep va sach se!",
                Rating = 5,
                Type = "review"
            };

            var ex = await Assert.ThrowsAsync<Exception>(() => reviewService.CreateReviewAsync(tenant.UserId, listing.ListingId, dto));
            Assert.Contains("đánh giá", ex.Message, StringComparison.OrdinalIgnoreCase);
        }

        [Fact]
        public async Task CreateReview_WithRenterStatus_ShouldSucceed()
        {
            var context = GetDatabaseContext();
            var fakeNotification = new FakeNotificationService();
            var fakeRealtimeNotifier = new FakeListingRealtimeNotifier();
            var reviewService = new ReviewService(context, fakeNotification);
            var rentalService = new RentalService(context, fakeRealtimeNotifier);

            var landlord = new User { UserId = 1, FullName = "Landlord", Phone = "0123456789", Email = "landlord@test.com" };
            var tenant = new User { UserId = 2, FullName = "Tenant", Phone = "0987654321", Email = "tenant@test.com" };
            var listing = CreateListing(landlord.UserId);

            await context.Users.AddRangeAsync(landlord, tenant);
            await context.ListingStatuses.AddRangeAsync(CreateListingStatuses());
            await context.Listings.AddAsync(listing);
            await context.SaveChangesAsync();

            await rentalService.CreateRentalAsync(landlord.UserId, listing.ListingId, new RentalCreateDto
            {
                TenantPhone = tenant.Phone,
                StartDate = DateTime.UtcNow
            });

            var dto = new ReviewCreateDto
            {
                Comment = "Phong rat dep va sach se!",
                Rating = 5,
                Type = "review"
            };

            var result = await reviewService.CreateReviewAsync(tenant.UserId, listing.ListingId, dto);

            Assert.NotNull(result);
            Assert.Equal("review", result.Type);
            Assert.Equal((byte)5, result.Rating);
            Assert.Equal("approved", result.Status);
            Assert.True(result.IsVerifiedTenant);
            Assert.NotEmpty(fakeNotification.SentNotifications);
            Assert.Equal(3, (await context.Listings.FindAsync(listing.ListingId))?.StatusId);
            Assert.Contains(fakeRealtimeNotifier.Events, e => e.ListingId == listing.ListingId && e.StatusName == "rented");
        }

        [Fact]
        public async Task SpamDetection_ShouldFlagSpamForUnverifiedTenants()
        {
            var context = GetDatabaseContext();
            var fakeNotification = new FakeNotificationService();
            var reviewService = new ReviewService(context, fakeNotification);

            var landlord = new User { UserId = 1, FullName = "Landlord", Phone = "0123456789", Email = "landlord@test.com" };
            var tenant = new User { UserId = 2, FullName = "Tenant", Phone = "0987654321", Email = "tenant@test.com" };
            var listing = CreateListing(landlord.UserId);

            await context.Users.AddRangeAsync(landlord, tenant);
            await context.Listings.AddAsync(listing);
            await context.SaveChangesAsync();

            var dto = new ReviewCreateDto
            {
                Comment = "Ghe qua trang web zalo.me/g/abccba de xem them phong",
                Type = "qna"
            };

            var result = await reviewService.CreateReviewAsync(tenant.UserId, listing.ListingId, dto);

            Assert.NotNull(result);
            Assert.Equal("pending", result.Status);
        }

        [Fact]
        public async Task SoftDeleteReview_ShouldSucceedWhenReplied()
        {
            var context = GetDatabaseContext();
            var fakeNotification = new FakeNotificationService();
            var reviewService = new ReviewService(context, fakeNotification);
            var rentalService = new RentalService(context, new FakeListingRealtimeNotifier());

            var landlord = new User { UserId = 1, FullName = "Landlord", Phone = "0123456789", Email = "landlord@test.com" };
            var tenant = new User { UserId = 2, FullName = "Tenant", Phone = "0987654321", Email = "tenant@test.com" };
            var listing = CreateListing(landlord.UserId);

            await context.Users.AddRangeAsync(landlord, tenant);
            await context.ListingStatuses.AddRangeAsync(CreateListingStatuses());
            await context.Listings.AddAsync(listing);
            await context.SaveChangesAsync();

            await rentalService.CreateRentalAsync(landlord.UserId, listing.ListingId, new RentalCreateDto
            {
                TenantPhone = tenant.Phone,
                StartDate = DateTime.UtcNow
            });

            var review = await reviewService.CreateReviewAsync(tenant.UserId, listing.ListingId, new ReviewCreateDto
            {
                Comment = "Review phan hoi",
                Rating = 4,
                Type = "review"
            });

            await reviewService.ReplyReviewAsync(landlord.UserId, review.ReviewId, new ReviewReplyDto { Reply = "Cam on ban!" });
            await reviewService.DeleteReviewAsync(tenant.UserId, review.ReviewId);

            var updatedReview = await context.Reviews.FindAsync(review.ReviewId);
            Assert.NotNull(updatedReview);
            Assert.True(updatedReview.IsDeleted);
            Assert.Equal("Bình luận này đã bị xóa.", updatedReview.Comment);
            Assert.Null(updatedReview.Rating);
        }

        [Fact]
        public async Task ReportReview_ShouldHideAfterThreshold()
        {
            var context = GetDatabaseContext();
            var fakeNotification = new FakeNotificationService();
            var reviewService = new ReviewService(context, fakeNotification);
            var rentalService = new RentalService(context, new FakeListingRealtimeNotifier());

            var landlord = new User { UserId = 1, FullName = "Landlord", Phone = "0123456789", Email = "landlord@test.com" };
            var tenant = new User { UserId = 2, FullName = "Tenant", Phone = "0987654321", Email = "tenant@test.com" };
            var listing = CreateListing(landlord.UserId);

            await context.Users.AddRangeAsync(landlord, tenant);
            await context.ListingStatuses.AddRangeAsync(CreateListingStatuses());
            await context.Listings.AddAsync(listing);
            await context.SaveChangesAsync();

            await rentalService.CreateRentalAsync(landlord.UserId, listing.ListingId, new RentalCreateDto
            {
                TenantPhone = tenant.Phone,
                StartDate = DateTime.UtcNow
            });

            var review = await reviewService.CreateReviewAsync(tenant.UserId, listing.ListingId, new ReviewCreateDto
            {
                Comment = "Binh luan xau xi",
                Rating = 1,
                Type = "review"
            });

            for (int i = 0; i < 5; i++)
            {
                await reviewService.ReportReviewAsync(landlord.UserId, review.ReviewId);
            }

            var updatedReview = await context.Reviews.FindAsync(review.ReviewId);
            Assert.NotNull(updatedReview);
            Assert.Equal("hidden", updatedReview.Status);
            Assert.False(updatedReview.IsApproved);
        }

        [Fact]
        public async Task CreateRental_WhenListingAlreadyHasActiveTenant_ShouldThrowException()
        {
            var context = GetDatabaseContext();
            var rentalService = new RentalService(context, new FakeListingRealtimeNotifier());

            var landlord = new User { UserId = 1, FullName = "Landlord", Phone = "0123456789", Email = "landlord@test.com" };
            var tenantA = new User { UserId = 2, FullName = "Tenant A", Phone = "0987654321", Email = "tenant-a@test.com" };
            var tenantB = new User { UserId = 3, FullName = "Tenant B", Phone = "0911222333", Email = "tenant-b@test.com" };
            var listing = CreateListing(landlord.UserId);

            await context.Users.AddRangeAsync(landlord, tenantA, tenantB);
            await context.ListingStatuses.AddRangeAsync(CreateListingStatuses());
            await context.Listings.AddAsync(listing);
            await context.SaveChangesAsync();

            await rentalService.CreateRentalAsync(landlord.UserId, listing.ListingId, new RentalCreateDto
            {
                TenantPhone = tenantA.Phone,
                StartDate = DateTime.UtcNow
            });

            var ex = await Assert.ThrowsAsync<Exception>(() => rentalService.CreateRentalAsync(
                landlord.UserId,
                listing.ListingId,
                new RentalCreateDto
                {
                    TenantPhone = tenantB.Phone,
                    StartDate = DateTime.UtcNow
                }));

            Assert.Contains("ngÆ°á»i thuÃª", ex.Message, StringComparison.OrdinalIgnoreCase);
        }
    }
}
