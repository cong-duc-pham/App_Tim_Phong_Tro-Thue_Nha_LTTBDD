using Microsoft.AspNetCore.Authentication.Cookies;

using Microsoft.AspNetCore.Authentication.JwtBearer;

using Microsoft.EntityFrameworkCore;

using Microsoft.IdentityModel.Tokens;

using Microsoft.OpenApi.Models;

using System.Reflection;

using System.Security.Claims;

using System.Text;

using FirebaseAdmin;

using Google.Apis.Auth.OAuth2;

using Backend_API.Models.Entities;

using Backend_API.Hubs;

using Backend_API.BackgroundTasks;

using Backend_API.Helpers;

using Backend_API.Services.Interfaces;

using Backend_API.Services.Implementations;

using Backend_API.Services;



var builder = WebApplication.CreateBuilder(args);

builder.Configuration.AddJsonFile(
    "appsettings.Local.json",
    optional: true,
    reloadOnChange: true);
builder.Configuration.AddEnvironmentVariables();



// ── Controllers (Web API & MVC Views)

builder.Services.AddControllersWithViews();

builder.Services.AddEndpointsApiExplorer();



// ── Swagger với hỗ trợ JWT Authorization + XML Docs

builder.Services.AddSwaggerGen(c =>

{

    c.SwaggerDoc("v1", new OpenApiInfo

    {

        Title = "PhongTro API",

        Version = "v1",

        Description = "API hệ thống tìm phòng trọ - thuê nhà. Hỗ trợ Auth, Listings, Chat, Payment, Notifications.",

        Contact = new OpenApiContact

        {

            Name = "PhongTro Team",

            Email = "support@phongtro.app"

        }

    });



    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme

    {

        Description = "JWT Authorization header. Nhập: Bearer {token}",

        Name = "Authorization",

        In = ParameterLocation.Header,

        Type = SecuritySchemeType.ApiKey,

        Scheme = "Bearer"

    });



    c.AddSecurityRequirement(new OpenApiSecurityRequirement

    {

        {

            new OpenApiSecurityScheme { Reference = new OpenApiReference { Type = ReferenceType.SecurityScheme, Id = "Bearer" } },

            Array.Empty<string>()

        }

    });



    // Include XML Comments from build output

    var xmlFilename = $"{Assembly.GetExecutingAssembly().GetName().Name}.xml";

    var xmlPath = Path.Combine(AppContext.BaseDirectory, xmlFilename);

    if (File.Exists(xmlPath))

    {

        c.IncludeXmlComments(xmlPath);

    }

});



// ── Database (EF Core + SQL Server)

var defaultConnection = builder.Configuration.GetConnectionString("DefaultConnection");

if (builder.Environment.IsProduction() && string.IsNullOrWhiteSpace(defaultConnection))

{

    throw new InvalidOperationException(

        "Production requires ConnectionStrings__DefaultConnection environment variable.");

}



builder.Services.AddDbContext<PhongTroDbContext>(options =>

    options.UseSqlServer(defaultConnection));



// ── Authentication (JWT + Cookie)

var jwtConfig = builder.Configuration.GetSection("JwtSettings");

var key = Encoding.UTF8.GetBytes(jwtConfig["SecretKey"]!);

builder.Services.AddAuthentication(options =>

    {

        options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;

        options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;

    })

    .AddJwtBearer(options =>

    {

        options.TokenValidationParameters = new TokenValidationParameters

        {

            ValidateIssuerSigningKey = true,

            IssuerSigningKey = new SymmetricSecurityKey(key),

            ValidateIssuer = true,

            ValidIssuer = jwtConfig["Issuer"],

            ValidateAudience = true,

            ValidAudience = jwtConfig["Audience"],

            ValidateLifetime = true,

            ClockSkew = TimeSpan.Zero

        };

        options.Events = new JwtBearerEvents

        {

            OnTokenValidated = async context =>

            {

                var userIdValue = context.Principal?.FindFirstValue(ClaimTypes.NameIdentifier);

                if (!long.TryParse(userIdValue, out var userId))

                {

                    context.Fail("Invalid user id.");

                    return;

                }



                var db = context.HttpContext.RequestServices.GetRequiredService<PhongTroDbContext>();

                var isActive = await db.Users

                    .AnyAsync(user => user.UserId == userId && user.IsActive == true);



                if (!isActive)

                {

                    context.Fail("User account is disabled.");

                }

            },

            OnMessageReceived = context =>

            {

                var accessToken = context.Request.Query["access_token"];

                var path = context.HttpContext.Request.Path;

                if (!string.IsNullOrEmpty(accessToken) &&

                    (path.StartsWithSegments("/hubs/chat") || path.StartsWithSegments("/hubs/listings")))

                {

                    context.Token = accessToken;

                }

                return Task.CompletedTask;

            }

        };

    })

    .AddCookie(options =>

    {

        options.LoginPath = "/auth/login";

        options.AccessDeniedPath = "/auth/login";

    });



// ── AutoMapper

builder.Services.AddAutoMapper(typeof(Program));



// ── Application Services

builder.Services.AddSingleton<JwtTokenHelper>();

builder.Services.AddSingleton<FirebaseHelper>();

builder.Services.AddSingleton<CloudinaryStorageHelper>();

builder.Services.AddSingleton<FirebaseMessagingHelper>();



builder.Services.AddScoped<IAuthService, AuthService>();

builder.Services.AddScoped<IEmailService, EmailService>();

builder.Services.AddScoped<ILocationService, LocationService>();

builder.Services.AddScoped<ICategoryService, CategoryService>();

builder.Services.AddScoped<IListingService, ListingService>();

builder.Services.AddScoped<IFavoriteService, FavoriteService>();

builder.Services.AddScoped<IReviewService, ReviewService>();

builder.Services.AddScoped<IRentalService, RentalService>();


builder.Services.AddScoped<IPreferenceService, PreferenceService>();

builder.Services.AddScoped<INotificationService, NotificationService>();

builder.Services.AddScoped<IConversationService, ConversationService>();

builder.Services.AddScoped<IPaymentService, PaymentService>();

builder.Services.AddScoped<IListingRealtimeNotifier, ListingRealtimeNotifier>();

builder.Services.AddHttpClient<IPayOsService, PayOsService>();

builder.Services.AddHttpClient<ITranslationService, GeminiTranslationService>();

builder.Services.AddHttpClient<IAiChatService, GeminiAiChatService>();

builder.Services.AddHttpClient();

builder.Services.AddScoped<ISmsService, SmsService>();



// ── Firebase (hỗ trợ env var FIREBASE_CREDENTIALS_JSON cho Docker)

var firebaseConfig = builder.Configuration.GetSection("Firebase");

var credentialPath = firebaseConfig["CredentialPath"] ?? "firebase-adminsdk.json";

var projectId = firebaseConfig["ProjectId"] ?? "app-tim-phong-tro-thue-n-dacfe";



// Ưu tiên biến môi trường FIREBASE_CREDENTIALS_JSON nếu có (dùng trong Docker/Cloud)

var firebaseCredJson = Environment.GetEnvironmentVariable("FIREBASE_CREDENTIALS_JSON");

if (!string.IsNullOrEmpty(firebaseCredJson))

{

    credentialPath = firebaseCredJson; // FirebaseCredentialLoader hỗ trợ cả JSON string

}

try

{

    FirebaseHelper.InitializeApp(credentialPath, projectId);

}

catch (Exception ex)

{

    if (builder.Environment.IsProduction())

    {

        throw;

    }



    Console.WriteLine($"[Firebase] Skipped Firebase Admin initialization: {ex.Message}");

}



// ── SignalR & Background Jobs

builder.Services.AddSignalR();

builder.Services.AddHostedService<DailyStatsJob>();

builder.Services.AddHostedService<VipExpiryWorker>();



// ── CORS (theo cấu hình AllowedOrigins)

var allowedOrigins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? Array.Empty<string>();



builder.Services.AddCors(options =>

{

    options.AddPolicy("FlutterDev", policy =>

    {

        if (allowedOrigins.Contains("*"))

        {

            policy.AllowAnyOrigin().AllowAnyMethod().AllowAnyHeader();

        }

        else

        {

            policy.WithOrigins(allowedOrigins).AllowAnyMethod().AllowAnyHeader();

        }

    });

});



var app = builder.Build();

app.UseStaticFiles();



// ── Middleware Pipeline



// Swagger: config-controlled (mặc định bật, tắt bằng Swagger:Enabled = false)

var swaggerEnabled = app.Configuration.GetValue<bool>("Swagger:Enabled", true);

if (swaggerEnabled)

{

    app.UseSwagger();

    app.UseSwaggerUI(c =>

    {

        c.SwaggerEndpoint("/swagger/v1/swagger.json", "PhongTro API v1");

        c.DocumentTitle = "PhongTro API - Swagger UI";

    });

}



app.UseCors("FlutterDev");

app.UseAuthentication();

app.UseAuthorization();

app.MapGet("/", () => Results.Content(

    "<h3>Backend API is running</h3><p><a href='/admin/dashboard'>Admin Dashboard</a> | <a href='/swagger'>Swagger</a></p>",

    "text/html"));

app.MapControllers();

app.MapControllerRoute(

    name: "default",

    pattern: "{controller=Home}/{action=Index}/{id?}");

app.MapHub<ChatHub>("/hubs/chat");

app.MapHub<ListingHub>("/hubs/listings");



app.Run();

