MERGE PostPackages AS target
USING (VALUES
    (N'Thường',          'free',      30,       0, 0,  1, 0, 0, NULL,       0, 0, N'Hiển thị bình thường, 1 ảnh đăng kèm, không badge, không thống kê lượt xem'),
    (N'VIP Tuần',        'vip',        7,   79000, 1,  5, 0, 0, 'vip',      1, 0, N'Ưu tiên hiển thị, tối đa 5 ảnh, badge VIP xanh, thống kê lượt xem'),
    (N'VIP Tháng',       'vip',       30,  299000, 2, 10, 1, 0, 'vip',      1, 0, N'Ưu tiên cao, tối đa 10 ảnh, badge VIP xanh, 1 video đăng kèm, thống kê lượt xem'),
    (N'Nổi bật 30 ngày', 'featured',  30,  499000, 3, 99, 3, 1, 'featured', 1, 1, N'Ưu tiên cao nhất, không giới hạn ảnh, badge nổi bật vàng, xuất hiện trên banner, 3 video đăng kèm, thống kê chi tiết')
) AS source (
    package_name,
    package_type,
    duration_days,
    price,
    priority,
    max_images,
    max_videos,
    allow_banner,
    badge_type,
    has_analytics,
    is_highlighted,
    description
)
ON target.package_type = source.package_type
   AND target.duration_days = source.duration_days
   AND (
       target.package_type <> 'vip'
       OR target.max_videos = source.max_videos
       OR target.package_name IN (N'Tin VIP 7 ngay', N'Tin VIP 30 ngay', N'VIP Tuần', N'VIP Tháng')
   )
WHEN MATCHED THEN
    UPDATE SET
        package_name = source.package_name,
        price = source.price,
        priority = source.priority,
        max_images = source.max_images,
        max_videos = source.max_videos,
        allow_banner = source.allow_banner,
        badge_type = source.badge_type,
        has_analytics = source.has_analytics,
        is_highlighted = source.is_highlighted,
        description = source.description,
        is_active = 1
WHEN NOT MATCHED BY TARGET THEN
    INSERT (
        package_name,
        package_type,
        duration_days,
        price,
        priority,
        max_images,
        max_videos,
        allow_banner,
        badge_type,
        has_analytics,
        is_highlighted,
        description,
        is_active
    )
    VALUES (
        source.package_name,
        source.package_type,
        source.duration_days,
        source.price,
        source.priority,
        source.max_images,
        source.max_videos,
        source.allow_banner,
        source.badge_type,
        source.has_analytics,
        source.is_highlighted,
        source.description,
        1
    );
