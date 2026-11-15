using PetShop.Hubs;
using PetShop.Models;

namespace PetShop.Tests;

/// <summary>
/// Unit test cho phần realtime HỘP THƯ CHAT của nhân viên (15/11/2026).
///
/// <para>
/// Phạm vi: phần logic tất định — tên group, tên event, cấu trúc payload.
/// Không test hub server (cần app + DB) — xem <c>NotificationHubTests</c>.
/// </para>
///
/// <para>
/// <b>VÌ SAO CẦN:</b> nhóm SignalR và tên event phải khớp ở MỌI nơi (server
/// push, hub join, client subscribe). Lệch 1 ký tự là client không nhận
/// được event ⇒ nhân viên không thấy tin của khách — đúng bug đang sửa.
/// </para>
/// </summary>
public class ChatInboxRealtimeTests
{
    // ---------------------------------------------------------------------
    // Group
    // ---------------------------------------------------------------------

    [Fact]
    public void UserGroup_TheoLoai_PhaiTachNhau_ChoIdTrungNhau()
    {
        // ⚠️ BUG GỐC (15/11/2026): các bảng người dùng có id TRÙNG NHAU
        // (staff_id = admin_id = doctor_id = customer_id = 1) ⇒ group chỉ theo
        // id làm tin bị đẩy nhầm giữa khách và nhân viên.
        Assert.Equal("staff:1", NotificationHub.UserGroup("staff", 1));
        Assert.Equal("admin:1", NotificationHub.UserGroup("admin", 1));
        Assert.Equal("doctor:1", NotificationHub.UserGroup("doctor", 1));
        Assert.Equal("customer:1", NotificationHub.UserGroup("customer", 1));

        // 4 người khác nhau ⇒ 4 group khác nhau.
        Assert.Equal(4, new[]
        {
            NotificationHub.UserGroup("staff", 1),
            NotificationHub.UserGroup("admin", 1),
            NotificationHub.UserGroup("doctor", 1),
            NotificationHub.UserGroup("customer", 1)
        }.Distinct().Count());
    }

    [Fact]
    public void StaffGroup_HangLaChatStaff()
    {
        // Nhân viên vào group này để nhận tin của MỌI khách (hộp thư chung).
        Assert.Equal("chat:staff", NotificationHub.StaffGroup);
    }

    [Fact]
    public void InboxGroup_TheoIdKhach()
    {
        // Nhân viên mở hộp thư khách X ⇒ vào group inbox:X.
        Assert.Equal("inbox:42", NotificationHub.InboxGroup(42));
        Assert.NotEqual(NotificationHub.InboxGroup(1), NotificationHub.InboxGroup(2));
    }

    [Fact]
    public void UserGroup_CuVanhDungChoChuongThongBao()
    {
        // Group cũ "user:{id}" giữ lại cho chuông thông báo đổi ca (tương thích).
        Assert.Equal("user:42", NotificationHub.UserGroup(42));
    }

    // ---------------------------------------------------------------------
    // Event
    // ---------------------------------------------------------------------

    [Fact]
    public void EventNames_MatchTheProtocolContract()
    {
        // Client subscribe đúng các tên này (RealtimeHubService) — lệch là hỏng.
        Assert.Equal("ChatTyping", NotificationHub.ChatTypingEvent);
        Assert.Equal("ChatPresence", NotificationHub.ChatPresenceEvent);
        Assert.Equal("ChatInboxChanged", NotificationHub.ChatInboxChangedEvent);
    }

    [Fact]
    public void EventNames_KhongTrungNhau()
    {
        // 3 event mới phải khác nhau, nếu không client đăng ký 2 handler trùng.
        var events = new[]
        {
            NotificationHub.ChatTypingEvent,
            NotificationHub.ChatPresenceEvent,
            NotificationHub.ChatInboxChangedEvent,
            NotificationHub.ChatReceivedEvent,
            NotificationHub.NotificationReceivedEvent
        };

        Assert.Equal(events.Length, events.Distinct().Count());
    }

    // ---------------------------------------------------------------------
    // Payload
    // ---------------------------------------------------------------------

    [Fact]
    public void ChatTypingDto_CarriesCustomer_StaffAndKind()
    {
        var dto = new ChatTypingDto(7, 3, "Phan Gia Hưng", IsTyping: true, SenderKind: "staff");

        Assert.Equal(7, dto.CustomerId);
        Assert.Equal(3, dto.StaffId);
        Assert.Equal("Phan Gia Hưng", dto.StaffName);
        Assert.True(dto.IsTyping);
        Assert.Equal("staff", dto.SenderKind);
    }

    [Fact]
    public void ChatTypingDto_MacDinhLaStaff_DeClientCuKhongCrash()
    {
        // Client cũ giải mã payload thiếu `senderKind` ⇒ phải có giá trị mặc định.
        var dto = new ChatTypingDto(1, 1);

        Assert.Equal("staff", dto.SenderKind);
        Assert.True(dto.IsTyping);
    }

    [Fact]
    public void ChatPresenceDto_CarriesOnlineState()
    {
        var dto = new ChatPresenceDto(7, 3, "Phan Gia Hưng", IsOnline: true);

        Assert.Equal(7, dto.CustomerId);
        Assert.Equal(3, dto.StaffId);
        Assert.True(dto.IsOnline);
    }

    [Fact]
    public void ChatPresenceDto_OfflineKhiKhongCoNguoiOnline()
    {
        var dto = new ChatPresenceDto(7, 0, "", IsOnline: false);

        Assert.False(dto.IsOnline);
        Assert.Equal(0, dto.StaffId);
    }

    [Fact]
    public void ChatInboxChangedDto_CarriesCustomerId_AndTimestamp()
    {
        var changedAt = new DateTime(2026, 11, 15, 9, 30, 0);
        var dto = new ChatInboxChangedDto(12, changedAt);

        Assert.Equal(12, dto.CustomerId);
        Assert.Equal(changedAt, dto.ChangedAt);
    }

    [Fact]
    public void ChatInboxItemDto_MacDinhKhongCoTinChuaDoc()
    {
        var item = new ChatInboxItemDto(5, "Nguyễn Văn A");

        Assert.Equal(5, item.CustomerId);
        Assert.Equal("Nguyễn Văn A", item.CustomerName);
        Assert.Equal(0, item.UnreadCount);
        Assert.False(item.HasUnread);
        Assert.False(item.LastMessageIsMine);
    }
}
