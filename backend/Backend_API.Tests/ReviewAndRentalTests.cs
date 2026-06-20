using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Backend_API.Models.DTOs.Reviews;
using Backend_API.Models.DTOs.Rentals;
using Backend_API.Models.DTOs.Notifications;
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
        private PhongTroDbContext GetDatabaseContext()
        {
            var options = new DbContextOptionsBuilder<PhongTroDbContext>()
                .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
                .Options;

            var context = new PhongTroDbContext(options);
            context.Database.EnsureCreated();
            return context;
        }

        [Fact]
        public async Task CreateQnaReview_ShouldSucceedWithoutRenterStatus()
        {
            // Arrange
            var context = GetDatabaseContext();
            var fakeNotification = new FakeNotificationService();
            var reviewService = new ReviewService(context, fakeNotification);

            var landlord = new User { UserId = 1, FullName = "Landlord", Phone = "0123456789", Email = "landlord@test.com" };
            var tenant = new User { UserId = 2, FullName = "Tenant", Phone = "0987654321", Email = "tenant@test.com" };
            var listing = new Listing { ListingId = 10, Title = "Phong Tro Dep", LandlordId = 1, Price = 1000000, StreetAddress = "123 Le Loi" };

            await context.Users.AddRangeAsync(landlord, tenant);
            await context.Listings.AddAsync(listing);
            await context.SaveChangesAsync();

            var dto = new ReviewCreateDto
            {
                Comment = "Toi muon hoi xem phong vao ngay mai duoc khong?",
                Type = "qna"
            };

            // Act
            var result = await reviewService.CreateReviewAsync(tenant.UserId, listing.ListingId, dto);

            // Assert
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
            // Arrange
            var context = GetDatabaseContext();
            var fakeNotification = new FakeNotificationService();
            var reviewService = new ReviewService(context, fakeNotification);

            var landlord = new User { UserId = 1, FullName = "Landlord", Phone = "0123456789", Email = "landlord@test.com" };
            var tenant = new User { UserId = 2, FullName = "Tenant", Phone = "0987654321", Email = "tenant@test.com" };
            var listing = new Listing { ListingId = 10, Title = "Phong Tro Dep", LandlordId = 1, Price = 1000000, StreetAddress = "123 Le Loi" };

            await context.Users.AddRangeAsync(landlord, tenant);
            await context.Listings.AddAsync(listing);
            await context.SaveChangesAsync();

            var dto = new ReviewCreateDto
            {
                Comment = "Phong rat dep va sach se!",
                Rating = 5,
                Type = "review"
            };

            // Act & Assert
            var ex = await Assert.ThrowsAsync<Exception>(() => reviewService.CreateReviewAsync(tenant.UserId, listing.ListingId, dto));
            Assert.Contains("Chỉ người dùng đã từng thuê phòng này mới được đánh giá", ex.Message);
        }

        [Fact]
        public async Task CreateReview_WithRenterStatus_ShouldSucceed()
        {
            // Arrange
            var context = GetDatabaseContext();
            var fakeNotification = new FakeNotificationService();
            var reviewService = new ReviewService(context, fakeNotification);
            var rentalService = new RentalService(context);

            var landlord = new User { UserId = 1, FullName = "Landlord", Phone = "0123456789", Email = "landlord@test.com" };
            var tenant = new User { UserId = 2, FullName = "Tenant", Phone = "0987654321", Email = "tenant@test.com" };
            var listing = new Listing { ListingId = 10, Title = "Phong Tro Dep", LandlordId = 1, Price = 1000000, StreetAddress = "123 Le Loi" };

            await context.Users.AddRangeAsync(landlord, tenant);
            await context.Listings.AddAsync(listing);
            await context.SaveChangesAsync();

            // Setup verified rental history
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

            // Act
            var result = await reviewService.CreateReviewAsync(tenant.UserId, listing.ListingId, dto);

            // Assert
            Assert.NotNull(result);
            Assert.Equal("review", result.Type);
            Assert.Equal((byte)5, result.Rating);
            Assert.Equal("approved", result.Status);
            Assert.True(result.IsVerifiedTenant);
            Assert.NotEmpty(fakeNotification.SentNotifications);
        }

        [Fact]
        public async Task SpamDetection_ShouldFlagSpamForUnverifiedTenants()
        {
            // Arrange
            var context = GetDatabaseContext();
            var fakeNotification = new FakeNotificationService();
            var reviewService = new ReviewService(context, fakeNotification);

            var landlord = new User { UserId = 1, FullName = "Landlord", Phone = "0123456789", Email = "landlord@test.com" };
            var tenant = new User { UserId = 2, FullName = "Tenant", Phone = "0987654321", Email = "tenant@test.com" };
            var listing = new Listing { ListingId = 10, Title = "Phong Tro Dep", LandlordId = 1, Price = 1000000, StreetAddress = "123 Le Loi" };

            await context.Users.AddRangeAsync(landlord, tenant);
            await context.Listings.AddAsync(listing);
            await context.SaveChangesAsync();

            var dto = new ReviewCreateDto
            {
                Comment = "Ghe qua trang web zalo.me/g/abccba de xem them phong",
                Type = "qna"
            };

            // Act
            var result = await reviewService.CreateReviewAsync(tenant.UserId, listing.ListingId, dto);

            // Assert
            Assert.NotNull(result);
            Assert.Equal("pending", result.Status); // Flagged because unverified
        }

        [Fact]
        public async Task SoftDeleteReview_ShouldSucceedWhenReplied()
        {
            // Arrange
            var context = GetDatabaseContext();
            var fakeNotification = new FakeNotificationService();
            var reviewService = new ReviewService(context, fakeNotification);
            var rentalService = new RentalService(context);

            var landlord = new User { UserId = 1, FullName = "Landlord", Phone = "0123456789", Email = "landlord@test.com" };
            var tenant = new User { UserId = 2, FullName = "Tenant", Phone = "0987654321", Email = "tenant@test.com" };
            var listing = new Listing { ListingId = 10, Title = "Phong Tro Dep", LandlordId = 1, Price = 1000000, StreetAddress = "123 Le Loi" };

            await context.Users.AddRangeAsync(landlord, tenant);
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

            // Landlord replies
            await reviewService.ReplyReviewAsync(landlord.UserId, review.ReviewId, new ReviewReplyDto { Reply = "Cam on ban!" });

            // Act
            await reviewService.DeleteReviewAsync(tenant.UserId, review.ReviewId);

            // Assert
            var updatedReview = await context.Reviews.FindAsync(review.ReviewId);
            Assert.NotNull(updatedReview);
            Assert.True(updatedReview.IsDeleted);
            Assert.Equal("Bình luận này đã bị xóa.", updatedReview.Comment);
            Assert.Null(updatedReview.Rating);
        }

        [Fact]
        public async Task ReportReview_ShouldHideAfterThreshold()
        {
            // Arrange
            var context = GetDatabaseContext();
            var fakeNotification = new FakeNotificationService();
            var reviewService = new ReviewService(context, fakeNotification);
            var rentalService = new RentalService(context);

            var landlord = new User { UserId = 1, FullName = "Landlord", Phone = "0123456789", Email = "landlord@test.com" };
            var tenant = new User { UserId = 2, FullName = "Tenant", Phone = "0987654321", Email = "tenant@test.com" };
            var listing = new Listing { ListingId = 10, Title = "Phong Tro Dep", LandlordId = 1, Price = 1000000, StreetAddress = "123 Le Loi" };

            await context.Users.AddRangeAsync(landlord, tenant);
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

            // Act: Report 5 times
            for (int i = 0; i < 5; i++)
            {
                await reviewService.ReportReviewAsync(landlord.UserId, review.ReviewId);
            }

            // Assert
            var updatedReview = await context.Reviews.FindAsync(review.ReviewId);
            Assert.NotNull(updatedReview);
            Assert.Equal("hidden", updatedReview.Status);
            Assert.False(updatedReview.IsApproved);
        }
    }
}
