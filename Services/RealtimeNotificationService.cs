using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Logging;
using PetShop.Hubs;
using PetShop.Interfaces;
using PetShop.Models;

namespace PetShop.Services;

/// <summary>
/// Đẩy thông báo / tin nhắn chat realtime tới client SignalR.
///
/// <para>
/// Dùng <see cref="IHubContext{THub}"/> nên có thể gọi từ bất kỳ tầng nào
/// (controller, service) — không cần giữ tham chiếu tới hub instance.
/// </para>
///
/// <para>
/// <b>Quy tắc quan trọng:</b> mọi lỗi đẩy dữ liệu đều được nuốt kèm log
/// <c>Warning</c>. Lỗi realtime không được làm hỏng luồng nghiệp vụ chính
/// (ví dụ <c>POST /api/shift-exchange/pass</c> phải trả 200 dù hub không kết nối được).
/// </para>
///
/// <para>
/// <b>⚠️ NHÓM THEO LOẠI NGƯỜI DÙNG (15/11/2026):</b> id các bảng người dùng
/// trùng nhau (staff_id = admin_id = doctor_id = customer_id = 1) ⇒ group chỉ
/// theo id (<c>"user:{id}"</c>) làm tin bị đẩy nhầm cho người khác. Vì vậy tin
/// chat được đẩy tới <c>"{kind}:{id}"</c> (xem <see cref="NotificationHub.UserGroup(string,int)"/>).
/// Group <c>"user:{id}"</c> vẫn giữ cho chuông thông báo đổi ca (tương thích).
/// </para>
/// </summary>
public sealed class RealtimeNotificationService : IRealtimeNotificationService
{
    private readonly IHubContext<NotificationHub> _hubContext;
    private readonly ILogger<RealtimeNotificationService> _logger;

    public RealtimeNotificationService(
        IHubContext<NotificationHub> hubContext,
        ILogger<RealtimeNotificationService> logger)
    {
        _hubContext = hubContext;
        _logger = logger;
    }

    /// <inheritdoc />
    public async Task NotifyAsync(
        int userId,
        string title,
        string message,
        int? relatedRequestId = null,
        CancellationToken cancellationToken = default)
    {
        if (userId <= 0)
        {
            _logger.LineWarning($"[Realtime] Bỏ qua notify vì userId không hợp lệ: {userId}");
            return;
        }

        try
        {
            var payload = new RealtimeNotificationDto(
                userId,
                title ?? string.Empty,
                message ?? string.Empty,
                relatedRequestId,
                DateTime.Now);

            await _hubContext.Clients
                .Group(NotificationHub.UserGroup(userId))
                .SendAsync(
                    NotificationHub.NotificationReceivedEvent,
                    payload,
                    cancellationToken);

            _logger.Line($"[Realtime] Đã push thông báo tới user:{userId} — {title}");
        }
        catch (OperationCanceledException)
        {
            // Huỷ có chủ đích (vd request client bị huỷ) — không log như lỗi.
            throw;
        }
        catch (Exception ex)
        {
            _logger.LineWarning($"[Realtime] Không push được thông báo tới user:{userId}: {ex.GetType().Name} — {ex.Message}");
        }
    }

    /// <inheritdoc />
    public async Task SendChatAsync(
        int toUserId,
        int fromUserId,
        string message,
        CancellationToken cancellationToken = default,
        int messageId = 0,
        string fromKind = "",
        string toKind = "",
        int toCustomerId = 0,
        string senderName = "",
        string senderRole = "")
    {
        if (toUserId <= 0)
        {
            _logger.LineWarning($"[Realtime] Bỏ qua chat vì toUserId không hợp lệ: {toUserId}");
            return;
        }

        try
        {
            var payload = new ChatEnvelope(
                toUserId,
                fromUserId,
                message ?? string.Empty,
                DateTime.Now,
                true,
                messageId,
                fromKind,
                toKind,
                toCustomerId,
                senderName,
                senderRole);

            // ⚠️ NHÓM THEO LOẠI (15/11/2026): `toKind` là loại của NGƯỜI NHẬN.
            //
            // VÌ SAO:
            //   id các bảng người dùng TRÙNG NHAU (customer 1 = staff 1 = admin 1).
            //   Group cũ "user:{id}" ⇒ tin của khách id=1 bị đẩy tới nhân viên id=1
            //   và ngược lại ⇒ lẫn hộp thư ⇒ nhân viên thấy tin của khách khác.
            //
            //   Nay dùng group "{toKind}:{toUserId}" ⇒ mỗi người chỉ nhận tin của
            //   chính mình (đúng không gian id của vai trò tương ứng).
            var targetKind = string.IsNullOrWhiteSpace(toKind)
                ? "customer"
                : toKind.Trim().ToLowerInvariant();

            await _hubContext.Clients
                .Group(NotificationHub.UserGroup(targetKind, toUserId))
                .SendAsync(
                    NotificationHub.ChatReceivedEvent,
                    payload,
                    cancellationToken);

            // ⚠️ HỘP THƯ CHUNG (13/11/2026): đẩy thêm tới group NHÂN VIÊN
            // ⇒ mọi nhân viên đều nhận tin của khách ngay, không chỉ người
            // được chọn (nay đã bỏ khái niệm "người được chọn").
            //
            // Client nhân viên lọc theo `ToCustomerId` để chỉ hiện tin thuộc hộp
            // thư đang mở; ai đang ở trang khác thì chỉ tăng badge.
            await _hubContext.Clients
                .Group(NotificationHub.StaffGroup)
                .SendAsync(
                    NotificationHub.ChatReceivedEvent,
                    payload,
                    cancellationToken);

            // ⚠️ NHÓM HỘP THƯ (15/11/2026): nhân viên đang mở hộp thư của khách
            // X cần nhận tin của đúng khách X (kể cả tin nhân viên KHÁC gửi) —
            // group staff chỉ nhận tin KHI KHÁCH gửi, còn tin nhân viên gửi thì
            // không đi qua group staff (xem ChatService.SendToCustomerAsync).
            if (toCustomerId > 0)
            {
                await _hubContext.Clients
                    .Group(NotificationHub.InboxGroup(toCustomerId))
                    .SendAsync(
                        NotificationHub.ChatReceivedEvent,
                        payload,
                        cancellationToken);
            }

            _logger.Line($"[Realtime] Đã push chat tới {targetKind}:{toUserId} + nhóm nhân viên từ {fromKind}:{fromUserId}");
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (Exception ex)
        {
            _logger.LineWarning($"[Realtime] Không push được chat tới {toUserId}: {ex.GetType().Name} — {ex.Message}");
        }
    }

    /// <inheritdoc />
    public async Task SendChatToInboxAsync(
        int customerId,
        string message,
        CancellationToken cancellationToken = default,
        int messageId = 0,
        string fromKind = "",
        int fromUserId = 0,
        string senderName = "",
        string senderRole = "")
    {
        if (customerId <= 0)
        {
            _logger.LineWarning($"[Realtime] Bỏ qua chat vì customerId không hợp lệ: {customerId}");
            return;
        }

        try
        {
            var payload = new ChatEnvelope(
                customerId,
                fromUserId,
                message ?? string.Empty,
                DateTime.Now,
                true,
                messageId,
                fromKind,
                "customer",
                customerId,
                senderName,
                senderRole);

            await _hubContext.Clients
                .Group(NotificationHub.InboxGroup(customerId))
                .SendAsync(
                    NotificationHub.ChatReceivedEvent,
                    payload,
                    cancellationToken);

            _logger.Line($"[Realtime] Đã push chat tới hộp thư inbox:{customerId} từ {fromKind}:{fromUserId}");
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (Exception ex)
        {
            _logger.LineWarning($"[Realtime] Không push được chat tới hộp thư inbox:{customerId}: {ex.GetType().Name} — {ex.Message}");
        }
    }

    /// <inheritdoc />
    public async Task SendTypingAsync(
        int customerId,
        int staffId,
        string staffName,
        bool isTyping,
        CancellationToken cancellationToken = default)
    {
        if (customerId <= 0)
        {
            return;
        }

        try
        {
            var payload = new ChatTypingDto(
                customerId,
                staffId,
                staffName ?? string.Empty,
                isTyping);

            await _hubContext.Clients
                .Group(NotificationHub.InboxGroup(customerId))
                .SendAsync(NotificationHub.ChatTypingEvent, payload, cancellationToken);

            await _hubContext.Clients
                .Group(NotificationHub.UserGroup("customer", customerId))
                .SendAsync(NotificationHub.ChatTypingEvent, payload, cancellationToken);

            _logger.Line($"[Realtime] Typing: staff={staffId}, customer={customerId}, isTyping={isTyping}");
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (Exception ex)
        {
            _logger.LineWarning($"[Realtime] Không push được trạng thái đang gõ cho hộp thư {customerId}: {ex.GetType().Name}");
        }
    }

    /// <inheritdoc />
    public async Task SendPresenceAsync(
        int customerId,
        int staffId,
        string staffName,
        bool isOnline,
        CancellationToken cancellationToken = default)
    {
        if (customerId <= 0)
        {
            return;
        }

        try
        {
            var payload = new ChatPresenceDto(
                customerId,
                staffId,
                staffName ?? string.Empty,
                isOnline);

            await _hubContext.Clients
                .Group(NotificationHub.InboxGroup(customerId))
                .SendAsync(NotificationHub.ChatPresenceEvent, payload, cancellationToken);

            await _hubContext.Clients
                .Group(NotificationHub.UserGroup("customer", customerId))
                .SendAsync(NotificationHub.ChatPresenceEvent, payload, cancellationToken);

            _logger.Line($"[Realtime] Presence: staff={staffId}, customer={customerId}, isOnline={isOnline}");
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (Exception ex)
        {
            _logger.LineWarning($"[Realtime] Không push được trạng thái online cho hộp thư {customerId}: {ex.GetType().Name}");
        }
    }

    /// <inheritdoc />
    public async Task NotifyInboxChangedAsync(
        int customerId,
        CancellationToken cancellationToken = default)
    {
        if (customerId <= 0)
        {
            return;
        }

        try
        {
            var payload = new ChatInboxChangedDto(customerId, DateTime.Now);

            await _hubContext.Clients
                .Group(NotificationHub.StaffGroup)
                .SendAsync(NotificationHub.ChatInboxChangedEvent, payload, cancellationToken);

            _logger.Line($"[Realtime] Hộp thư inbox:{customerId} có thay đổi.");
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (Exception ex)
        {
            _logger.LineWarning($"[Realtime] Không push được thông báo thay đổi hộp thư {customerId}: {ex.GetType().Name}");
        }
    }
}
