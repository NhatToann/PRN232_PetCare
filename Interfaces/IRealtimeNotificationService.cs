namespace PetShop.Interfaces;

/// <summary>
/// Dịch vụ đẩy dữ liệu realtime (SignalR) tới client.
///
/// <para>
/// Đây là tầng "service" của luồng 3-layer: Razor/Controller → <b>IRealtimeNotificationService</b>
/// → <c>IHubContext&lt;NotificationHub&gt;</c>. Component Razor <b>không</b> được gọi
/// thẳng vào <c>IHubContext</c> và <b>không</b> được inject
/// <c>ShopPetDatabaseContext</c> (xem AGENTS.md §2.3 / kiến trúc 3-layer).
/// </para>
///
/// <para>
/// Mọi lỗi push đều được nuốt kèm log — lỗi realtime KHÔNG được làm hỏng luồng
/// nghiệp vụ chính (ví dụ: gửi yêu cầu đổi ca vẫn phải trả 200 dù SignalR hỏng).
/// </para>
/// </summary>
public interface IRealtimeNotificationService
{
    /// <summary>
    /// Đẩy một thông báo tới nhân viên <paramref name="userId"/>.
    /// </summary>
    /// <param name="userId">Id nhân viên nhận thông báo.</param>
    /// <param name="title">Tiêu đề (ví dụ "Yêu cầu đổi ca").</param>
    /// <param name="message">Nội dung thông báo.</param>
    /// <param name="relatedRequestId">Id yêu cầu liên quan (nếu có).</param>
    /// <param name="cancellationToken">Token huỷ.</param>
    Task NotifyAsync(
        int userId,
        string title,
        string message,
        int? relatedRequestId = null,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Đẩy một tin nhắn chat tới <paramref name="toUserId"/> VÀ tới nhóm nhân viên.
    ///
    /// <para>
    /// <b>HỘP THƯ CHUNG (13/11/2026):</b> tin gửi từ khách phải tới ĐỒNG THỜI:
    /// group cá nhân của khách (khách thấy tin của mình) + group
    /// <c>chat:staff</c> (mọi nhân viên thấy tin của khách).
    /// </para>
    ///
    /// <para>
    /// <b>⚠️ (15/11/2026):</b> group cá nhân nay được đẩy theo CẢ LOẠI người dùng
    /// (<c>{kind}:{id}</c>) vì id các bảng người dùng trùng nhau ⇒ group chỉ theo
    /// id làm tin của khách id=1 đến nhầm nhân viên id=1.
    /// </para>
    /// </summary>
    /// <param name="toUserId">Id người nhận (khách hàng trong luồng hộp thư chung).</param>
    /// <param name="fromUserId">Id người gửi.</param>
    /// <param name="message">Nội dung tin nhắn.</param>
    /// <param name="cancellationToken">Token huỷ.</param>
    /// <param name="messageId">
    /// Id bản ghi trong bảng <c>ChatMessages</c> (Q21) — client dùng để chống
    /// hiển thị trùng khi nhận tin qua cả realtime lẫn HTTP. Bằng <c>0</c> nếu
    /// tin chưa được ghi log.
    /// </param>
    /// <param name="fromKind">
    /// Loại người gửi: <c>staff</c> / <c>admin</c> / <c>doctor</c> / <c>customer</c>.
    /// Bắt buộc vì id các bảng trùng nhau (xem <c>ChatEnvelope.FromKind</c>).
    /// </param>
    /// <param name="toKind">
    /// Loại người nhận: <c>staff</c> / <c>admin</c> / <c>doctor</c> / <c>customer</c>.
    /// </param>
    /// <param name="toCustomerId">
    /// Id khách mà tin thuộc về — client nhân viên dùng để lọc đúng hộp thư.
    /// </param>
    /// <param name="senderName">Tên hiển thị của người gửi.</param>
    /// <param name="senderRole">Vai trò của người gửi.</param>
    Task SendChatAsync(
        int toUserId,
        int fromUserId,
        string message,
        CancellationToken cancellationToken = default,
    int messageId = 0,
    string fromKind = "",
    string toKind = "",
    int toCustomerId = 0,
    string senderName = "",
    string senderRole = "");

    /// <summary>
    /// Đẩy tin nhắn chat tới hộp thư của một khách (group <c>inbox:{customerId}</c>).
    ///
    /// <para>
    /// <b>VÌ SAO CẦN (15/11/2026):</b> nhân viên đang mở hộp thư khách X vào
    /// group <c>inbox:X</c> ⇒ nhận được tin của đúng khách đó (kể cả tin nhân
    /// viên khác gửi) mà không cần nhận toàn bộ tin của mọi khách.
    /// </para>
    /// </summary>
    /// <param name="customerId">Id khách hàng (khoá hộp thư).</param>
    /// <param name="message">Nội dung tin nhắn.</param>
    /// <param name="cancellationToken">Token huỷ.</param>
    /// <param name="messageId">Id bản ghi trong bảng <c>ChatMessages</c>.</param>
    /// <param name="fromKind">Loại người gửi.</param>
    /// <param name="fromUserId">Id người gửi.</param>
    /// <param name="senderName">Tên hiển thị của người gửi.</param>
    /// <param name="senderRole">Vai trò của người gửi.</param>
    Task SendChatToInboxAsync(
        int customerId,
        string message,
        CancellationToken cancellationToken = default,
        int messageId = 0,
        string fromKind = "",
        int fromUserId = 0,
        string senderName = "",
        string senderRole = "");

    /// <summary>
    /// Báo "nhân viên đang gõ" trong hộp thư của khách.
    /// </summary>
    /// <param name="customerId">Id khách hàng (hộp thư đang gõ).</param>
    /// <param name="staffId">Id nhân viên đang gõ.</param>
    /// <param name="staffName">Tên nhân viên.</param>
    /// <param name="isTyping"><c>true</c> = đang gõ, <c>false</c> = đã dừng.</param>
    /// <param name="cancellationToken">Token huỷ.</param>
    Task SendTypingAsync(
        int customerId,
        int staffId,
        string staffName,
        bool isTyping,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Báo trạng thái online của nhân viên trong hộp thư của khách.
    /// </summary>
    /// <param name="customerId">Id khách hàng (hộp thư).</param>
    /// <param name="staffId">Id nhân viên (0 = không còn ai online).</param>
    /// <param name="staffName">Tên nhân viên.</param>
    /// <param name="isOnline">Có nhân viên nào đang online trong hộp thư không.</param>
    /// <param name="cancellationToken">Token huỷ.</param>
    Task SendPresenceAsync(
        int customerId,
        int staffId,
        string staffName,
        bool isOnline,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Báo hộp thư của khách X vừa thay đổi ⇒ cập nhật badge số tin chưa đọc.
    /// </summary>
    /// <param name="customerId">Id khách hàng (hộp thư thay đổi).</param>
    /// <param name="cancellationToken">Token huỷ.</param>
    Task NotifyInboxChangedAsync(
        int customerId,
        CancellationToken cancellationToken = default);
}
