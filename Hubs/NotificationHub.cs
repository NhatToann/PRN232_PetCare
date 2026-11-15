using System.Security.Claims;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using PetShop.Data;
using PetShop.Models;
using PetShop.Services;

namespace PetShop.Hubs;

/// <summary>
/// Hub SignalR cho thông báo realtime + chat (LS-11).
///
/// Được đăng ký tại <c>/hubs/notification</c> (xem <c>Program.cs</c>).
///
/// <para><b>Cơ chế nhận diện người dùng (3 tầng, theo thứ tự ưu tiên):</b></para>
/// <list type="number">
///   <item>
///     <description>
///     <c>Authorization: Bearer &lt;JWT&gt;</c> hoặc header session nội bộ
///     (<c>X-User-Id</c>) ⇒ đọc claim <see cref="ClaimTypes.NameIdentifier"/>.
///     Đây là danh tính <b>thật</b> — dùng để ghi lịch sử chat.
///     </description>
///   </item>
///   <item>
///     <description>
///     Query string <c>?userId=...&amp;role=...</c> ⇒ danh tính <b>phi xác thực</b>
///     (LOCAL DEMO). Chỉ dùng để vào group nhận thông báo; <b>không</b> ghi vào
///     bảng <c>ChatMessages</c> để không ghi nhận tin nhắn của người chưa xác thực.
///     </description>
///   </item>
///   <item>
///     <description>
///     Không có gì ⇒ <see cref="HubException"/>, không cho tham gia group nào.
///     </description>
///   </item>
/// </list>
///
/// <para>
/// <b>⚠️ NHÓM THEO LOẠI NGƯỜI DÙNG (15/11/2026):</b> trước đây group là
/// <c>"user:{id}"</c> — CHỈ id. Nhưng các bảng người dùng có id TRÙNG NHAU
/// (đã kiểm tra DB: <c>staff_id</c> / <c>admin_id</c> / <c>doctor_id</c> /
/// <c>customer_id</c> đều có 1, 2, 6, 7, 8) ⇒ nhân viên id=1 và khách id=1
/// cùng nằm trong group <c>user:1</c> ⇒ tin của khách bị đẩy tới nhân viên
/// và tin của nhân viên bị đẩy tới khách ⇒ lẫn hộp thư.
/// </para>
///
/// <para>
/// Nay group = <c>"{kind}:{id}"</c> (vd <c>"staff:1"</c>, <c>"customer:1"</c>)
/// ⇒ mỗi người chỉ nhận tin của chính mình. Group cũ <c>"user:{id}"</c> được
/// giữ lại cho <b>tương thích ngược</b> (chuông thông báo đổi ca cũng dùng
/// group này) nhưng <b>không</b> dùng cho chat nữa.
/// </para>
///
/// <para>
/// Ngoài group cá nhân, mỗi người còn vào:
/// <list type="bullet">
///   <item><description>
///     <see cref="StaffGroup"/> — mọi nhân viên (chỉ nhân viên mới vào) ⇒ nhận
///     tin của MỌI khách, lọc theo <c>ToCustomerId</c>.
///   </description></item>
///   <item><description>
///     <see cref="InboxGroup"/> — nhân viên mở hộp thư của khách X ⇒ vào
///     group <c>inbox:{customerId}</c> ⇒ nhận tin của đúng khách đó (kể cả tin
///     nhân viên khác gửi) mà không cần bật cả nhóm staff.
///   </description></item>
/// </list>
/// </para>
/// </summary>
public sealed class NotificationHub : Hub
{
    /// <summary>Prefix tên group theo user — dùng chung với service phía server.</summary>
    public const string UserGroupPrefix = "user:";

    /// <summary>
    /// Group NHÂN VIÊN — mọi nhân viên (staff / admin / doctor) cùng nhận tin.
    ///
    /// <para>
    /// <b>VÌ SAO CẦN (13/11/2026):</b> luồng chat khách ↔ nhân viên nay là
    /// <b>HỘP THƯ CHUNG</b> — khách nhắn 1 lần ⇒ MỌI nhân viên phải thấy
    /// (không chỉ 1 người được chọn) ⇒ cần 1 group chung cho toàn bộ nhân viên.
    /// Client nhân viên lọc theo <c>ToCustomerId</c> để biết tin đó thuộc hộp
    /// thư của khách nào.
    /// </para>
    /// </summary>
    public const string StaffGroup = "chat:staff";

    /// <summary>
    /// Prefix group HỘP THƯ theo khách — nhân viên mở hộp thư của khách X thì
    /// vào group <c>inbox:{customerId}</c>.
    ///
    /// <para>
    /// <b>VÌ SAO CẦN (15/11/2026):</b> group staff gửi TIN CỦA MỌI KHÁCH về
    /// cho mọi nhân viên ⇒ 20 nhân viên × 60 khách = rất nhiều event thừa.
    /// Group theo hộp thư ⇒ nhân viên chỉ nhận tin của khách mình đang mở.
    /// </para>
    /// </summary>
    public const string InboxGroupPrefix = "inbox:";

    /// <summary>Tên event mà client nhận thông báo mới.</summary>
    public const string NotificationReceivedEvent = "NotificationReceived";

    /// <summary>Tên event mà client nhận tin nhắn chat.</summary>
    public const string ChatReceivedEvent = "ChatReceived";

    /// <summary>Tên event "nhân viên đang gõ" (typing indicator).</summary>
    public const string ChatTypingEvent = "ChatTyping";

    /// <summary>Tên event trạng thái online của nhân viên (presence).</summary>
    public const string ChatPresenceEvent = "ChatPresence";

    /// <summary>
    /// Event báo "hộp thư của khách X có tin mới" — dùng để cập nhật danh sách
    /// hộp thư (badge số tin chưa đọc) mà không cần tải lại cả danh sách.
    /// </summary>
    public const string ChatInboxChangedEvent = "ChatInboxChanged";

    /// <summary>
    /// Khoá cache trong <see cref="HubCallerContext.Items"/> lưu loại người dùng
    /// của connection (dùng để các lệnh sau định danh đúng người gọi).
    /// </summary>
    private const string KindCacheKey = "petshop:kind";

    /// <summary>
    /// Khoá cache trong <see cref="HubCallerContext.Items"/> lưu id người gọi.
    /// </summary>
    private const string UserIdCacheKey = "petshop:userId";

    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<NotificationHub> _logger;

    public NotificationHub(IServiceScopeFactory scopeFactory, ILogger<NotificationHub> logger)
    {
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    /// <summary>
    /// Tên group của một user — dùng để join/leave và để service push tới đúng người.
    /// </summary>
    public static string UserGroup(int userId) => $"{UserGroupPrefix}{userId}";

    /// <summary>
    /// Tên group CÁ NHÂN có kèm loại người dùng — dùng cho chat.
    ///
    /// <para>
    /// <b>VÌ SAO CẦN (15/11/2026):</b> id các bảng người dùng trùng nhau
    /// (staff_id = admin_id = doctor_id = customer_id = 1) ⇒ group chỉ theo id
    /// làm tin bị đẩy nhầm cho người khác. Kèm <paramref name="kind"/> thì
    /// mỗi người có group riêng.
    /// </para>
    /// </summary>
    /// <param name="kind">Loại người dùng: <c>staff</c> / <c>admin</c> / <c>doctor</c> / <c>customer</c>.</param>
    /// <param name="userId">Id người dùng.</param>
    public static string UserGroup(string kind, int userId) => $"{kind}:{userId}";

    /// <summary>
    /// Tên group HỘP THƬ của một khách — nhân viên mở hộp thư khách X thì vào
    /// group này để nhận đúng tin của khách đó.
    /// </summary>
    /// <param name="customerId">Id khách hàng.</param>
    public static string InboxGroup(int customerId) => $"{InboxGroupPrefix}{customerId}";

    /// <summary>
    /// Vào group nhận thông báo của <paramref name="userId"/>.
    ///
    /// <para>
    /// Người dùng chỉ được vào group của chính mình: nếu request đã xác thực
    /// (Bearer/session header) thì <paramref name="userId"/> phải khớp claim
    /// <see cref="ClaimTypes.NameIdentifier"/>, nếu không sẽ ném
    /// <see cref="HubException"/>. Ở chế độ query string (chưa xác thực) thì
    /// dùng luôn <paramref name="userId"/> do client truyền — xem ghi chú ở
    /// phần tổng quan về chế độ LOCAL DEMO.
    /// </para>
    ///
    /// <para>
    /// <b>Nhân viên (13/11/2026):</b> ngoài group cá nhân, nhân viên còn được
    /// tham gia <see cref="StaffGroup"/> (hộp thư chung) để nhận tin của KHÁCH
    /// mà không cần ai gán tay.
    /// </para>
    ///
    /// <para>
    /// <b>⚠️ THAM SỐ <paramref name="role"/> (15/11/2026):</b> URL hub của client
    /// Blazor <b>không</b> mang header session ⇒ với query string không có
    /// <c>role</c>, hàm <see cref="ResolveIdentity"/> sẽ coi người đó là
    /// <c>customer</c> ⇒ nhân viên KHÔNG BAO GIỜ vào được <see cref="StaffGroup"/>
    /// ⇒ nhân viên không nhận được tin của khách ⇒ đây chính là nguyên nhân
    /// "nhân viên không thấy tin khách nhắn". Nay client truyền kèm <c>role</c>.
    /// </para>
    /// </summary>
    /// <param name="userId">Id người dùng.</param>
    /// <param name="role">
    /// Loại người dùng: <c>staff</c> / <c>admin</c> / <c>doctor</c> / <c>customer</c>.
    /// Bắt buộc cho nhân viên (để vào <see cref="StaffGroup"/>).
    /// </param>
    public async Task JoinGroup(int userId, string? role = null)
    {
        if (userId <= 0)
        {
            throw new HubException("userId không hợp lệ.");
        }

        var identity = ResolveIdentity(userId, role);

        // Cache lại danh tính (role do client truyền là nguồn chính xác nhất).
        CacheIdentity(identity);

        if (identity.IsAuthenticated && identity.UserId != userId)
        {
            throw new HubException("Không được tham gia group của người khác.");
        }

        await Groups.AddToGroupAsync(Context.ConnectionId, UserGroup(userId));

        // Group CÁ NHÂN theo loại — dùng cho chat (tách id trùng nhau).
        await Groups.AddToGroupAsync(Context.ConnectionId, UserGroup(identity.Kind, userId));

        // Hộp thư chung — chỉ nhân viên mới vào group này.
        if (IsStaffKind(identity.Kind))
        {
            await Groups.AddToGroupAsync(Context.ConnectionId, StaffGroup);
        }

        _logger.Line($"[NotificationHub] JoinGroup: connection={Context.ConnectionId}, userId={userId}, authenticated={identity.IsAuthenticated}, kind={identity.Kind}, groups=[user:{userId}, {identity.Kind}:{userId}{(IsStaffKind(identity.Kind) ? ", " + StaffGroup : string.Empty)}]");
    }

    /// <summary>
    /// Vào group HỘP THƯ của một khách (nhân viên đang mở hộp thư khách đó).
    ///
    /// <para>
    /// <b>KHÔNG dùng cho khách hàng:</b> khách chỉ cần nhận tin trong hộp thư
    /// của CHÍNH MÌNH ⇒ group <c>{kind}:{id}</c> đã đủ.
    /// </para>
    /// </summary>
    /// <param name="customerId">Id khách hàng (khoá hộp thư).</param>
    public async Task JoinInbox(int customerId)
    {
        if (customerId <= 0)
        {
            throw new HubException("customerId không hợp lệ.");
        }

        var identity = ResolveIdentity(customerId, null);

        // ⚠️ CHẾ ĐỘ LOCAL DEMO (15/11/2026): client Blazor kết nối hub bằng
        // query string (`?userId=..&role=..`) ⇒ KHÔNG có claim ⇒
        // `IsAuthenticated == false`. Nếu kiểm tra chặt `IsAuthenticated` thì
        // mọi lệnh của client (join hộp thư, báo typing) đều bị từ chối ⇒
        // nhân viên không mở được hộp thư realtime.
        //
        // ⇒ Chỉ kiểm tra LOẠI người dùng (`kind`), không kiểm tra IsAuthenticated.
        // Đây là đánh đổi chấp nhận được của dự án LOCAL (xem AGENTS.md §0).
        if (!IsStaffKind(identity.Kind))
        {
            throw new HubException("Chỉ nhân viên mới được theo dõi hộp thư của khách hàng.");
        }

        await Groups.AddToGroupAsync(Context.ConnectionId, InboxGroup(customerId));

        _logger.Line($"[NotificationHub] JoinInbox: connection={Context.ConnectionId}, customerId={customerId}, staffId={identity.UserId}, kind={identity.Kind}");
    }

    /// <summary>
    /// Rời group HỘP THƬ của một khách (nhân viên đóng hộp thư).
    /// </summary>
    /// <param name="customerId">Id khách hàng (khoá hộp thư).</param>
    public async Task LeaveInbox(int customerId)
    {
        if (customerId <= 0)
        {
            return;
        }

        await Groups.RemoveFromGroupAsync(Context.ConnectionId, InboxGroup(customerId));

        _logger.Line($"[NotificationHub] LeaveInbox: connection={Context.ConnectionId}, customerId={customerId}");
    }

    /// <summary>
    /// Rời group của <paramref name="userId"/>.
    /// </summary>
    public async Task LeaveGroup(int userId)
    {
        if (userId <= 0)
        {
            throw new HubException("userId không hợp lệ.");
        }

        var identity = ResolveIdentity(userId, null);

        if (identity.IsAuthenticated && identity.UserId != userId)
        {
            throw new HubException("Không được thao tác group của người khác.");
        }

        await Groups.RemoveFromGroupAsync(Context.ConnectionId, UserGroup(userId));
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, UserGroup(identity.Kind, userId));

        _logger.Line($"[NotificationHub] LeaveGroup: connection={Context.ConnectionId}, userId={userId}, kind={identity.Kind}");
    }

    /// <summary>
    /// Gửi tin nhắn chat 1-1 tới <paramref name="userId"/>.
    ///
    /// <para>
    /// Tin nhắn được gửi tới group <c>user:{userId}</c> và echo lại cho người gọi
    /// qua <c>Clients.Caller</c> (event <see cref="ChatReceivedEvent"/>) để người gửi
    /// cũng thấy tin nhắn của mình.
    /// </para>
    ///
    /// <para>
    /// <b>Chống giả mạo:</b> người gửi được lấy từ claim
    /// <see cref="ClaimTypes.NameIdentifier"/> (hoặc query string ở chế độ demo) —
    /// <b>không</b> tin <paramref name="userId"/> do client gửi cho việc ghi log.
    /// </para>
    /// </summary>
    public async Task SendMessage(int userId, string message)
    {
        if (userId <= 0)
        {
            throw new HubException("userId không hợp lệ.");
        }

        if (string.IsNullOrWhiteSpace(message))
        {
            throw new HubException("Nội dung tin nhắn không được để trống.");
        }

        var identity = ResolveIdentity(userId, null);

        if (!identity.IsAuthenticated)
        {
            // LOCAL DEMO: chỉ cho "nhận" tin nhắn, không ghi log chat để tránh
            // lẫn dữ liệu của người chưa xác thực vào bảng ChatMessages.
            await Clients.Caller.SendAsync(ChatReceivedEvent, new ChatEnvelope(
                userId,
                identity.UserId,
                message,
                DateTime.Now,
                false));

            _logger.LineWarning($"[NotificationHub] SendMessage bị từ chối ghi log: connection={Context.ConnectionId} chưa xác thực.");

            return;
        }

        var senderId = identity.UserId;

        // Ghi lịch sử vào bảng ChatMessages (bảng đã có sẵn trong schema).
        await SaveChatMessageAsync(senderId, userId, message);

        await Clients.Group(UserGroup(userId)).SendAsync(ChatReceivedEvent, new ChatEnvelope(
            userId,
            senderId,
            message,
            DateTime.Now,
            true));

        // Echo lại cho người gửi (nếu người gửi cũng đang ở group của chính mình).
        await Clients.Caller.SendAsync(ChatReceivedEvent, new ChatEnvelope(
            senderId,
            senderId,
            message,
            DateTime.Now,
            true));

        _logger.Line($"[NotificationHub] SendMessage: from={senderId}, to={userId}, authenticated={identity.IsAuthenticated}");
    }

    /// <summary>
    /// Báo "đang gõ" trong hộp thư của một khách.
    ///
    /// <para>
    /// Chạy 2 chiều: nhân viên gõ ⇒ khách thấy "nhân viên đang gõ…";
    /// khách gõ ⇒ nhân viên thấy "khách đang gõ…" (biết khách đang chờ).
    /// </para>
    /// </summary>
    /// <param name="customerId">Id khách hàng (hộp thư đang gõ).</param>
    /// <param name="isTyping"><c>true</c> = đang gõ, <c>false</c> = đã dừng.</param>
    public async Task SendTyping(int customerId, bool isTyping)
    {
        if (customerId <= 0)
        {
            throw new HubException("customerId không hợp lệ.");
        }

        var identity = ResolveIdentity(customerId, null);

        // ⚠️ Xem giải thích chế độ LOCAL DEMO ở `JoinInbox`: chỉ kiểm tra LOẠI
        // người dùng, không kiểm tra `IsAuthenticated` (client Blazor kết nối hub
        // bằng query string ⇒ không có claim).
        if (identity.Kind == ChatRepositoryKindValue.Customer && identity.UserId != customerId)
        {
            throw new HubException("Chỉ được báo trạng thái đang gõ trong hộp thư của chính mình.");
        }

        var senderName = await ResolveDisplayNameAsync(identity);

        var payload = new ChatTypingDto(
            customerId,
            identity.UserId,
            senderName,
            isTyping,
            identity.Kind);

        // Tới nhân viên đang mở hộp thư + tới khách của hộp thư đó.
        await Clients.Group(InboxGroup(customerId)).SendAsync(ChatTypingEvent, payload);
        await Clients.Group(UserGroup(ChatRepositoryKindValue.Customer, customerId)).SendAsync(ChatTypingEvent, payload);

        _logger.Line($"[NotificationHub] SendTyping: from={identity.UserId} ({identity.Kind}), customer={customerId}, isTyping={isTyping}");
    }

    /// <summary>
    /// Tra tên hiển thị của người đang chat theo loại tài khoản.
    ///
    /// <para>
    /// Dùng cho typing indicator — khách cần biết "ai đang gõ" (nhân viên nào),
    /// chứ không chỉ "có ai đang gõ".
    /// </para>
    /// </summary>
    private async Task<string> ResolveDisplayNameAsync(HubIdentity identity)
    {
        try
        {
            await using var scope = _scopeFactory.CreateAsyncScope();
            var db = scope.ServiceProvider.GetRequiredService<ShopPetDatabaseContext>();

            var name = identity.Kind switch
            {
                ChatRepositoryKindValue.Admin => await db.Admins
                    .AsNoTracking()
                    .Where(a => a.AdminId == identity.UserId)
                    .Select(a => a.Name ?? a.Username)
                    .FirstOrDefaultAsync(),
                ChatRepositoryKindValue.Doctor => await db.Doctors
                    .AsNoTracking()
                    .Where(d => d.DoctorId == identity.UserId)
                    .Select(d => d.Name)
                    .FirstOrDefaultAsync(),
                ChatRepositoryKindValue.Staff => await db.Staff
                    .AsNoTracking()
                    .Where(s => s.StaffId == identity.UserId)
                    .Select(s => s.Name)
                    .FirstOrDefaultAsync(),
                _ => await db.Customers
                    .AsNoTracking()
                    .Where(c => c.CustomerId == identity.UserId)
                    .Select(c => c.Name)
                    .FirstOrDefaultAsync()
            };

            return string.IsNullOrWhiteSpace(name) ? "Người dùng" : name!;
        }
        catch (Exception ex)
        {
            _logger.LineWarning($"[NotificationHub] Không tra được tên hiển thị (id={identity.UserId}, kind={identity.Kind}): {ex.GetType().Name}");
            return "Người dùng";
        }
    }

    /// <summary>
    /// Báo trạng thái online của nhân viên trong hộp thư của khách.
    /// </summary>
    /// <param name="customerId">Id khách hàng (hộp thư).</param>
    /// <param name="isOnline"><c>true</c> = nhân viên đang mở hộp thư này.</param>
    public async Task SendPresence(int customerId, bool isOnline)
    {
        if (customerId <= 0)
        {
            throw new HubException("customerId không hợp lệ.");
        }

        var identity = ResolveIdentity(customerId, null);

        // ⚠️ Xem giải thích chế độ LOCAL DEMO ở `JoinInbox`: chỉ kiểm tra LOẠI
        // người dùng, không kiểm tra `IsAuthenticated`.
        if (!IsStaffKind(identity.Kind))
        {
            throw new HubException("Chỉ nhân viên mới được báo trạng thái online.");
        }

        var payload = new ChatPresenceDto(
            customerId,
            identity.UserId,
            await ResolveDisplayNameAsync(identity),
            isOnline);

        await Clients.Group(InboxGroup(customerId)).SendAsync(ChatPresenceEvent, payload);
        await Clients.Group(UserGroup(ChatRepositoryKindValue.Customer, customerId)).SendAsync(ChatPresenceEvent, payload);

        _logger.Line($"[NotificationHub] SendPresence: staff={identity.UserId}, customer={customerId}, isOnline={isOnline}");
    }

    /// <summary>
    /// Báo hộp thư của khách X vừa có thay đổi (có tin mới / đã đọc).
    ///
    /// <para>
    /// Dùng để danh sách hộp thư của nhân viên cập nhật badge số tin chưa đọc
    /// mà không cần tải lại toàn bộ danh sách từ DB.
    /// </para>
    /// </summary>
    /// <param name="customerId">Id khách hàng (hộp thư thay đổi).</param>
    public async Task NotifyInboxChanged(int customerId)
    {
        if (customerId <= 0)
        {
            return;
        }

        await Clients.Group(StaffGroup).SendAsync(ChatInboxChangedEvent, new ChatInboxChangedDto(
            customerId,
            DateTime.Now));

        _logger.Line($"[NotificationHub] NotifyInboxChanged: customer={customerId}");
    }

    /// <summary>
    /// Được gọi khi client kết nối. Không chặn kết nối: nếu chưa xác thực thì client
    /// tự gọi <see cref="JoinGroup"/> sau khi negotiate.
    /// </summary>
    public override Task OnConnectedAsync()
    {
        var identity = ResolveIdentity(0, null);

        // ⚠️ CACHE DANH TÍNH (15/11/2026):
        //   Khi client SignalR đã "negotiate" xong, các lệnh hub tiếp theo chạy
        //   qua WebSocket ⇒ `Context.GetHttpContext()` trả `null` ⇒ đọc query
        //   string `?userId=..&role=..` KHÔNG còn được ⇒ lệnh `JoinInbox` /
        //   `SendTyping` sẽ resolve ra "customer" ⇒ bị từ chối ⇒ nhân viên
        //   không mở được hộp thư realtime.
        //
        //   ⇒ Cache lại danh tính lúc connect (query string còn đọc được ở
        //   OnConnectedAsync) để các lệnh sau dùng lại được.
        CacheIdentity(identity);

        _logger.Line($"[NotificationHub] OnConnected: connection={Context.ConnectionId}, authenticated={identity.IsAuthenticated}, userId={identity.UserId}, kind={identity.Kind}");

        return base.OnConnectedAsync();
    }

    /// <summary>
    /// Ghi nhớ danh tính của connection vào <see cref="HubCallerContext.Items"/>.
    /// </summary>
    private void CacheIdentity(HubIdentity identity)
    {
        try
        {
            Context.Items[KindCacheKey] = identity.Kind;
            Context.Items[UserIdCacheKey] = identity.UserId;
        }
        catch (Exception ex)
        {
            _logger.LineWarning($"[NotificationHub] Không cache được danh tính connection: {ex.GetType().Name}");
        }
    }

    /// <summary>
    /// Ghi một tin nhắn chat vào bảng <c>ChatMessages</c>.
    ///
    /// <para>
    /// Bảng có cột <c>CustomerID</c> (bắt buộc, FK sang <c>Customer</c>) và
    /// <c>StaffID</c> (nullable, FK sang <c>Admin</c>). Vì đây là chat giữa các
    /// nhân viên, ta ghi <c>CustomerId</c> = id người nhận và <c>StaffId</c> =
    /// id người gửi (nếu id người gửi có tồn tại trong bảng <c>Staff</c>).
    /// </para>
    ///
    /// <para>
    /// <b>HỘP THƯ CHUNG (13/11/2026):</b> ghi thêm <c>SenderName</c> +
    /// <c>SenderKind</c> để mọi nhân viên thấy AI là người gửi (cột
    /// <c>SenderType</c> bị CHECK constraint chỉ cho phép 'Staff'/'Customer').
    /// </para>
    /// </summary>
    private async Task SaveChatMessageAsync(int senderId, int receiverId, string message)
    {
        try
        {
            await using var scope = _scopeFactory.CreateAsyncScope();
            var db = scope.ServiceProvider.GetRequiredService<ShopPetDatabaseContext>();

            var receiverExists = await db.Customers
                .AsNoTracking()
                .AnyAsync(c => c.CustomerId == receiverId);

            if (!receiverExists)
            {
                _logger.LineWarning($"[NotificationHub] Bỏ qua ghi log chat: Customer #{receiverId} không tồn tại.");
                return;
            }

            var senderIsStaff = await db.Staff
                .AsNoTracking()
                .AnyAsync(s => s.StaffId == senderId);

            var senderName = await db.Staff
                .AsNoTracking()
                .Where(s => s.StaffId == senderId)
                .Select(s => s.Name)
                .FirstOrDefaultAsync();

            var entity = new ChatMessage
            {
                CustomerId = receiverId,
                StaffId = senderIsStaff ? senderId : null,
                SenderType = senderIsStaff ? "staff" : "customer",
                SenderName = senderName,
                SenderKind = senderIsStaff ? "staff" : "customer",
                Message = message,
                SentAt = DateTime.Now,
                IsRead = false,
            };

            db.ChatMessages.Add(entity);
            await db.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            // Lỗi ghi log chat KHÔNG được làm hỏng luồng gửi tin nhắn.
            _logger.LineError(ex, $"[NotificationHub] Không ghi được lịch sử chat (from={senderId}, to={receiverId}): {ex.Message}");
        }
    }

    /// <summary>
    /// Xác định danh tính của connection hiện tại.
    /// </summary>
    /// <param name="requestedUserId">Id người dùng do client truyền (fallback).</param>
    /// <param name="roleHint">
    /// Loại người dùng do client truyền kèm (chế độ LOCAL DEMO qua query
    /// string). Cần cho <see cref="JoinGroup"/> vì URL hub của client Blazor
    /// không mang header session.
    /// </param>
    private HubIdentity ResolveIdentity(int requestedUserId, string? roleHint)
    {
        var principal = Context.User;

        if (principal?.Identity?.IsAuthenticated == true)
        {
            var raw = principal.FindFirstValue(ClaimTypes.NameIdentifier);
            var role = principal.FindFirstValue(ClaimTypes.Role);
            var kind = NormalizeKind(role);

            if (int.TryParse(raw, out var userId) && userId > 0)
            {
                return new HubIdentity(userId, true, kind);
            }
        }

        // ⚠️ ƯU TIÊN 1 — cache của connection (15/11/2026).
        //
        // VÌ SAO:
        //   Sau khi negotiate xong, các lệnh hub chạy qua WebSocket ⇒
        //   `Context.GetHttpContext()` = null ⇒ không đọc được query string.
        //   Cache lúc `OnConnectedAsync` (còn đọc được) là nguồn duy nhất
        //   còn lại ⇒ bắt buộc phải dùng.
        //
        //   Nhưng nếu client truyền `roleHint` rõ ràng (lệnh `JoinGroup`
        //   truyền role) thì `roleHint` mới là nguồn chính xác hơn.
        var cachedKind = ReadCachedKind();
        var cachedUserId = ReadCachedUserId();

        // LOCAL DEMO — chưa xác thực: đọc userId từ query string của lúc negotiate.
        var query = Context.GetHttpContext()?.Request.Query;
        if (query is not null)
        {
            var rawQuery = query["userId"].ToString();
            var roleQuery = query["role"].ToString();

            // ƯU TIÊN `roleHint` (client truyền trực tiếp qua lệnh JoinGroup)
            // → `role` trong query string → mặc định customer.
            var effectiveRole = !string.IsNullOrWhiteSpace(roleHint)
                ? roleHint
                : (string.IsNullOrWhiteSpace(roleQuery) ? null : roleQuery);

            var kind = NormalizeKind(effectiveRole);

            if (int.TryParse(rawQuery, out var queryUserId) && queryUserId > 0)
            {
                return new HubIdentity(queryUserId, false, kind);
            }
        }

        // ⚠️ ƯU TIÊN 2 — dùng cache của connection (query string không còn).
        if (cachedUserId > 0)
        {
            // `roleHint` rõ ràng (client truyền qua `JoinGroup`) là nguồn chính
            // xác hơn ⇒ ưu tiên; nếu không có thì lấy kind đã cache.
            var kind = !string.IsNullOrWhiteSpace(roleHint)
                ? NormalizeKind(roleHint)
                : cachedKind;

            return new HubIdentity(cachedUserId, false, kind);
        }

        return new HubIdentity(requestedUserId, false, NormalizeKind(roleHint));
    }

    /// <summary>Đọc loại người dùng đã cache cho connection (rỗng nếu chưa có).</summary>
    private string ReadCachedKind() =>
        Context.Items.TryGetValue(KindCacheKey, out var value) && value is string kind
            ? kind
            : string.Empty;

    /// <summary>Đọc id người dùng đã cache cho connection (0 nếu chưa có).</summary>
    private int ReadCachedUserId() =>
        Context.Items.TryGetValue(UserIdCacheKey, out var value) && value is int userId
            ? userId
            : 0;

    /// <summary>
    /// Chuẩn hoá role của người dùng về loại dùng trong chat.
    /// </summary>
    /// <param name="role">Role thô.</param>
    /// <returns><c>staff</c> / <c>admin</c> / <c>doctor</c> / <c>customer</c>.</returns>
    private static string NormalizeKind(string? role) => (role ?? string.Empty).Trim().ToLowerInvariant() switch
    {
        "admin" => ChatRepositoryKindValue.Admin,
        "doctor" => ChatRepositoryKindValue.Doctor,
        "staff" or "manager" or "employee" => ChatRepositoryKindValue.Staff,
        _ => ChatRepositoryKindValue.Customer,
    };

    /// <summary>Kiểm tra loại người dùng có phải nhân viên (được vào hộp thư chung) không.</summary>
    private static bool IsStaffKind(string? kind) =>
        kind is ChatRepositoryKindValue.Staff or ChatRepositoryKindValue.Admin or ChatRepositoryKindValue.Doctor;

    /// <summary>
    /// Kết quả resolve danh tính của một connection.
    /// </summary>
    /// <param name="UserId">Id người dùng suy ra được.</param>
    /// <param name="IsAuthenticated"><c>true</c> nếu danh tính đến từ claim hợp lệ.</param>
    /// <param name="Kind">Loại người dùng: <c>staff</c> / <c>admin</c> / <c>doctor</c> / <c>customer</c>.</param>
    private readonly record struct HubIdentity(int UserId, bool IsAuthenticated, string Kind);

    /// <summary>
    /// Hằng số loại người dùng — dùng trong hub để tránh phụ thuộc vào tầng
    /// service (giữ đúng nguyên tắc 3-layer của dự án).
    /// </summary>
    private static class ChatRepositoryKindValue
    {
        public const string Staff = "staff";
        public const string Admin = "admin";
        public const string Doctor = "doctor";
        public const string Customer = "customer";
    }
}
