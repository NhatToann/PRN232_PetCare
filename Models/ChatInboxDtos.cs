using System;

namespace PetShop.Models;

/// <summary>
/// Một ô hộp thư của khách hàng (dùng trong màn hình Inbox của nhân viên).
///
/// <para>
/// <b>VÌ SAO CẦN (15/11/2026):</b> luồng chat khách ↔ nhân viên là
/// <b>hộp thư chung</b> theo khách ⇒ nhân viên cần một danh sách "hộp thư"
/// để duyệt qua, biết hộp thư nào có tin chưa đọc, tin mới đến lúc nào.
/// Không có DTO này thì nhân viên phải nhớ ai vừa nhắn ⇒ dễ bỏ sót khách.
/// </para>
/// </summary>
/// <param name="CustomerId">Id khách hàng (khoá hộp thư).</param>
/// <param name="CustomerName">Tên khách hàng.</param>
/// <param name="AvatarUrl">Ảnh đại diện khách (data-URI hoặc http/https).</param>
/// <param name="Email">Email khách (tiện khi cần tra cứu).</param>
/// <param name="Phone">Số điện thoại khách.</param>
/// <param name="LastMessage">Nội dung tin nhắn cuối cùng (rút gọn để hiển thị).</param>
/// <param name="LastMessageAt">Thời điểm tin nhắn cuối cùng.</param>
/// <param name="LastMessageIsMine">
/// <c>true</c> nếu tin cuối cùng do chính nhân viên đang xem gửi.
/// </param>
/// <param name="UnreadCount">Số tin khách gửi mà nhân viên chưa đọc.</param>
/// <param name="HasUnread">Có tin chưa đọc hay không (tiện render badge).</param>
public sealed record ChatInboxItemDto(
    int CustomerId,
    string CustomerName,
    string? AvatarUrl = null,
    string? Email = null,
    string? Phone = null,
    string LastMessage = "",
    DateTime? LastMessageAt = null,
    bool LastMessageIsMine = false,
    int UnreadCount = 0,
    bool HasUnread = false);

/// <summary>
/// Báo "hộp thư của khách X vừa thay đổi" (có tin mới / đánh dấu đã đọc).
///
/// <para>
/// <b>VÌ SAO CẦN (15/11/2026):</b> danh sách hộp thư của nhân viên cần cập
/// nhật badge "số tin chưa đọc" ngay khi có tin mới, mà không cần tải lại
/// toàn bộ danh sách từ DB (tốn round-trip + RAM).
/// </para>
/// </summary>
/// <param name="CustomerId">Id khách hàng (hộp thư thay đổi).</param>
/// <param name="ChangedAt">Thời điểm thay đổi.</param>
public sealed record ChatInboxChangedDto(
    int CustomerId,
    DateTime ChangedAt);

/// <summary>
/// Trạng thái nhân viên đang "gõ" trong một hộp thư (typing indicator).
///
/// <para>
/// <b>VÌ SAO CẦN (15/11/2026):</b> khách nhắn mà không thấy phản hồi thì hay
/// nhắn lại hoặc bỏ đi. Hiện "nhân viên đang gõ" là tín hiệu nhỏ nhưng quyết
/// định ⇒ giữ khách ở lại chat.
/// </para>
/// </summary>
/// <param name="CustomerId">Id khách mà tin nhắn đang gõ thuộc về.</param>
/// <param name="StaffId">Id người đang gõ (nhân viên hoặc khách — xem <paramref name="SenderKind"/>).</param>
/// <param name="StaffName">Tên người đang gõ (để khách thấy "X đang gõ…").</param>
/// <param name="IsTyping"><c>true</c> = đang gõ, <c>false</c> = đã dừng gõ.</param>
/// <param name="SenderKind">
/// Loại người đang gõ: <c>staff</c> / <c>admin</c> / <c>doctor</c> / <c>customer</c>.
///
/// <para>
/// <b>VÌ SAO CẦN (15/11/2026):</b> typing indicator chạy 2 chiều — nhân viên
/// gõ ⇒ khách thấy "nhân viên đang gõ…"; khách gõ ⇒ nhân viên thấy "khách đang
/// gõ…" (biết khách đang chờ trả lời) ⇒ cần biết AI đang gõ để hiển thị đúng
/// nhãn, không cứ mặc định là "nhân viên".
/// </para>
/// </param>
public sealed record ChatTypingDto(
    int CustomerId,
    int StaffId,
    string StaffName = "",
    bool IsTyping = true,
    string SenderKind = "staff");

/// <summary>
/// Trạng thái online của nhân viên trong hộp thư (presence).
///
/// <para>
/// <b>VÌ SAO CẦN (15/11/2026):</b> khách cần biết "có người phản hồi được
/// không" trước khi hỏi ⇒ nếu không có nhân viên online thì nên chuyển sang
/// hỏi AI thay vì chờ vô ích.
/// </para>
/// </summary>
/// <param name="CustomerId">Id khách (hộp thư đang xem).</param>
/// <param name="StaffId">Id nhân viên (0 = không còn ai online).</param>
/// <param name="StaffName">Tên nhân viên đang online.</param>
/// <param name="IsOnline">Có nhân viên nào đang online trong hộp thư không.</param>
public sealed record ChatPresenceDto(
    int CustomerId,
    int StaffId = 0,
    string StaffName = "",
    bool IsOnline = false);
