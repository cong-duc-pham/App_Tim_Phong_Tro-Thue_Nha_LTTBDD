# Firebase Cloud Messaging (FCM) Security - Phase 9.2

## Kết luận nhanh
FCM **không có Security Rules** như Storage/Firestore.
Yêu cầu bảo mật cho FCM trong production là: **chỉ server (Admin SDK) được quyền gửi**.

## Quy tắc triển khai
- Flutter client chỉ:
  - nhận notification
  - gửi device token lên backend (`/api/auth/update-fcm-token`)
- Backend mới được gửi push thông qua Firebase Admin SDK.
- Không expose service account JSON qua API/public repo.

## Checklist xác nhận "server-only sending"
- [x] Backend có `FirebaseMessagingHelper` để gửi push
- [x] Client không chứa server key/service account
- [x] `firebase-adminsdk.json` không commit vào Git
- [x] Production inject credential qua file mount/secret manager

## Hardening khuyến nghị
1. Rotate service account key định kỳ.
2. Giới hạn quyền service account theo nguyên tắc least privilege.
3. Log toàn bộ hành động gửi notification ở backend (audit).
4. Bật App Check cho Firebase app để giảm abuse từ client giả mạo.

## Ghi chú
Nếu cần enforce ai được gửi push theo business rule (owner/admin), làm tại API layer
bằng JWT + authorization policy. Đây là nơi thay thế cho "FCM rules".
