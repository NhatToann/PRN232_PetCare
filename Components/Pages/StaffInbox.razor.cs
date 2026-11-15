using Microsoft.AspNetCore.Components;
using Microsoft.AspNetCore.Components.Web;
using Microsoft.Extensions.Logging;
using Microsoft.JSInterop;
using PetShop.Interfaces;
using PetShop.Models;
using PetShop.Services;

namespace PetShop_PRN222.Components.Pages;

/// <summary>
/// Code-behind của <c>StaffInbox.razor</c> — màn hình hộp thư chat của nhân viên.
///
/// <para>
/// <b>Kiến trúc (3-layer):</b> Component → <see cref="IChatClient"/> (self-HTTP
/// tới <c>api/chat/*</c>) → Controller → <see cref="IChatService"/> →
/// Repository → DB. Component <b>không</b> inject DbContext.
/// </para>
///
/// <para>
/// <b>Realtime:</b> dùng chung <see cref="RealtimeHubService"/> của circuit
/// (1 WebSocket cho cả chuông + widget chat + trang này).
/// </para>
/// </summary>
public partial class StaffInbox : ComponentBase, IAsyncDisposable
{
    /// <summary>Id khung chứa danh sách tin nhắn (dùng cho JS interop).</summary>
    private const string MessagesBoxId = "staffInboxMessages";

    /// <summary>Số tin nhắn tối đa giữ trong RAM của circuit.</summary>
    private const int MaxMessages = 150;

    [Inject] private IChatClient ChatClient { get; set; } = default!;

    [Inject] private UserSessionService UserSession { get; set; } = default!;

    [Inject] private NavigationManager Navigation { get; set; } = default!;

    [Inject] private RealtimeHubService Realtime { get; set; } = default!;

    [Inject] private ILogger<StaffInbox> Logger { get; set; } = default!;

    [Inject] private IJSRuntime JS { get; set; } = default!;

    /// <summary>Danh sách hộp thư (tất cả khách đã từng nhắn).</summary>
    private readonly List<ChatInboxItemDto> inbox = new();

    /// <summary>Tin nhắn của hộp thư đang mở.</summary>
    private readonly List<ChatTurn> messages = new();

    private bool loading;
    private bool threadLoading;
    private bool sending;
    private bool realtimeConnected;
    private string? error;
    private string draft = string.Empty;
    private string searchText = string.Empty;

    /// <summary>Id khách của hộp thư đang mở (0 = chưa chọn).</summary>
    private int selectedCustomerId;

    /// <summary>Khách đang gõ trong hộp thư đang mở (null = không ai gõ).</summary>
    private ChatTypingDto? typingIndicator;

    /// <summary>Có nhân viên nào đang online trong hộp thư này không.</summary>
    private bool presenceOnline;

    /// <summary>Khóa hủy typing — dùng để gửi "đã dừng gõ" sau 2 giây.</summary>
    private CancellationTokenSource? typingCts;

    // ---------------------------------------------------------------------
    // Thuộc tính hiển thị
    // ---------------------------------------------------------------------

    /// <summary>Danh sách hộp thư đầy đủ.</summary>
    private IReadOnlyList<ChatInboxItemDto> Inbox => inbox;

    /// <summary>
    /// Danh sách hộp thư đã lọc theo từ khoá tìm kiếm.
    /// </summary>
    private IReadOnlyList<ChatInboxItemDto> FilteredInbox
    {
        get
        {
            var keyword = searchText.Trim();

            if (keyword.Length == 0)
            {
                return inbox;
            }

            return inbox
                .Where(i => i.CustomerName.Contains(keyword, StringComparison.OrdinalIgnoreCase)
                            || (i.Email ?? string.Empty).Contains(keyword, StringComparison.OrdinalIgnoreCase)
                            || (i.Phone ?? string.Empty).Contains(keyword, StringComparison.OrdinalIgnoreCase))
                .ToList();
        }
    }

    /// <summary>Hộp thư đang mở (null nếu chưa chọn khách nào).</summary>
    private ChatInboxItemDto? Selected =>
        inbox.FirstOrDefault(i => i.CustomerId == selectedCustomerId);

    /// <summary>Tin nhắn của hộp thư đang mở (đã sắp xếp tăng dần theo thời gian).</summary>
    private IReadOnlyList<ChatTurn> Messages => messages;

    /// <summary>Tổng số tin chưa đọc (badge đầu trang).</summary>
    private int UnreadTotal => inbox.Sum(i => i.UnreadCount);

    /// <summary>Đang tải danh sách hộp thư hay không.</summary>
    private bool Loading => loading;

    /// <summary>Đang tải lịch sử hộp thư đang mở hay không.</summary>
    private bool ThreadLoading => threadLoading;

    /// <summary>Đang gửi tin hay không.</summary>
    private bool Sending => sending;

    /// <summary>Kết nối realtime có thành công không.</summary>
    private bool RealtimeConnected => realtimeConnected;

    /// <summary>Thông báo lỗi.</summary>
    private string? Error => error;

    /// <summary>Nội dung ô nhập.</summary>
    private string Draft => draft;

    /// <summary>Từ khoá tìm kiếm khách trong danh sách hộp thư.</summary>
    private string SearchText => searchText;

    /// <summary>Id khách của hộp thư đang mở (0 = chưa chọn).</summary>
    private int SelectedCustomerId => selectedCustomerId;

    /// <summary>Khách đang gõ (null nếu không ai gõ).</summary>
    private ChatTypingDto? TypingIndicator => typingIndicator;

    /// <summary>Có nhân viên đang online trong hộp thư đang m�y không.</summary>
    private bool PresenceOnline => presenceOnline;

    /// <summary>Loại người dùng hiện tại (staff / admin / doctor).</summary>
    private string CurrentRole => (UserSession.CurrentUser?.Role ?? string.Empty).Trim().ToLowerInvariant();

    /// <summary>Id người dùng hiện tại.</summary>
    private int CurrentUserId => UserSession.CurrentUser?.UserId ?? 0;

    /// <summary>Tên hiển thị của người đang đăng nhập.</summary>
    private string CurrentUserDisplayName => UserSession.CurrentUser?.Name ?? "Nhân viên";

    /// <summary>
    /// Người dùng hiện tại có phải nhân viên không.
    ///
    /// <para>
    /// Chỉ nhân viên (staff / admin / doctor) mới có hộp thư. Khách vào trang
    /// này sẽ bị chuyển về trang chủ (guard ở layout + kiểm tra ở đây).
    /// </para>
    /// </summary>
    private bool IsStaffSide => CurrentRole is "staff" or "admin" or "doctor";

    // ---------------------------------------------------------------------
    // Vòng đời
    // ---------------------------------------------------------------------

    protected override async Task OnInitializedAsync()
    {
        Realtime.ChatReceived += HandleChatReceived;
        Realtime.ChatTypingReceived += HandleTypingReceived;
        Realtime.ChatPresenceReceived += HandlePresenceReceived;
        Realtime.ChatInboxChanged += HandleInboxChanged;

        try
        {
            await UserSession.LoadAsync();
        }
        catch (Exception ex)
        {
            Logger.LineWarning($"[StaffInbox] UserSession.LoadAsync threw: {ex.GetType().Name}");
        }

        if (!IsStaffSide)
        {
            error = "Chỉ nhân viên mới truy cập được hộp thư chat.";
            return;
        }

        await StartRealtimeAsync();
        await LoadInboxAsync();
    }

    /// <summary>
    /// Bảo đảm kết nối SignalR (dùng chung với chuông + widget chat).
    ///
    /// <para>
    /// ⚠️ PHẢI truyền <c>role</c> — nếu không, server coi mọi người là "customer"
    /// ⇒ nhân viên không vào được group <c>chat:staff</c> ⇒ không nhận được tin
    /// của khách nhắn (bug "nhân viên không thấy tin").
    /// </para>
    /// </summary>
    private async Task StartRealtimeAsync()
    {
        var userId = CurrentUserId;

        if (userId <= 0)
        {
            return;
        }

        try
        {
            var baseUri = Navigation.BaseUri;
            var separator = baseUri.Contains('?', StringComparison.Ordinal) ? '&' : '?';

            var url = $"{baseUri.TrimEnd('/')}{RealtimeHubService.HubPath}{separator}userId={userId}";

            if (!string.IsNullOrWhiteSpace(CurrentRole))
            {
                url += $"&role={Uri.EscapeDataString(CurrentRole)}";
            }

            await Realtime.EnsureConnectedAsync(url, userId, CurrentRole);
            realtimeConnected = Realtime.IsConnected;
        }
        catch (Exception ex)
        {
            realtimeConnected = false;
            Logger.LineWarning($"[StaffInbox] Không kết nối được SignalR (fallback sang HTTP): {ex.GetType().Name}");
        }
    }

    // ---------------------------------------------------------------------
    // Realtime handlers
    // ---------------------------------------------------------------------

    /// <summary>
    /// Tin nhắn mới tới — thêm vào khung chat nếu đúng hộp thư, ngược lại tăng
    /// badge + cập nhật danh sách hộp thư.
    /// </summary>
    private void HandleChatReceived(ChatEnvelope chat)
    {
        try
        {
            // Chặn echo của chính mình (tin đã thêm qua HTTP rồi).
            var ownKind = IChatService.NormalizeKind(CurrentRole);
            var isOwnEcho = chat.FromUserId == CurrentUserId
                && (string.IsNullOrWhiteSpace(chat.FromKind)
                    || string.Equals(chat.FromKind, ownKind, StringComparison.OrdinalIgnoreCase));

            if (isOwnEcho)
            {
                return;
            }

            var customerId = chat.ToCustomerId > 0 ? chat.ToCustomerId : chat.UserId;

            if (customerId <= 0)
            {
                return;
            }

            if (customerId == selectedCustomerId)
            {
                if (!messages.Any(m => m.ExternalId == chat.MessageId && chat.MessageId != 0))
                {
                    messages.Add(new ChatTurn(
                        chat.Message,
                        string.IsNullOrWhiteSpace(chat.SenderName) ? "Khách hàng" : chat.SenderName,
                        string.IsNullOrWhiteSpace(chat.SenderRole) ? "customer" : chat.SenderRole,
                        false,
                        chat.SentAt,
                        NextSequence(),
                        chat.MessageId));

                    TrimMessages();
                }
            }

            // Cập nhật badge + tin cuối cùng trong danh sách hộp thư.
            UpdateInboxPreview(customerId, chat.Message, chat.SentAt, isFromCustomer: !IsStaffSender(chat));

            InvokeAsync(StateHasChanged);
            _ = InvokeAsync(ScrollToBottomAsync);
        }
        catch (Exception ex)
        {
            Logger.LineWarning($"[StaffInbox] Không xử lý được tin realtime: {ex.GetType().Name}");
        }
    }

    /// <summary>
    /// Khách đang gõ trong hộp thư đang mở ⇒ hiện dấu "…".
    /// </summary>
    private void HandleTypingReceived(ChatTypingDto typing)
    {
        try
        {
            if (typing.CustomerId != selectedCustomerId)
            {
                return;
            }

            typingIndicator = typing.IsTyping ? typing : null;

            InvokeAsync(StateHasChanged);
        }
        catch (Exception ex)
        {
            Logger.LineWarning($"[StaffInbox] Không xử lý được sự kiện typing: {ex.GetType().Name}");
        }
    }

    /// <summary>
    /// Trạng thái online của nhân viên (hộp thư chung ⇒ có thể có nhiều người).
    /// </summary>
    private void HandlePresenceReceived(ChatPresenceDto presence)
    {
        try
        {
            if (presence.CustomerId != selectedCustomerId)
            {
                return;
            }

            presenceOnline = presence.IsOnline;

            InvokeAsync(StateHasChanged);
        }
        catch (Exception ex)
        {
            Logger.LineWarning($"[StaffInbox] Không xử lý được sự kiện presence: {ex.GetType().Name}");
        }
    }

    /// <summary>
    /// Hộp thư của khách X vừa thay đổi ⇒ tải lại danh sách (badge chính xác).
    /// </summary>
    private void HandleInboxChanged(ChatInboxChangedDto changed)
    {
        try
        {
            if (changed.CustomerId == selectedCustomerId)
            {
                // Hộp thư đang mở — chỉ cần cập nhật số chưa đọc.
                InvokeAsync(async () =>
                {
                    await LoadInboxAsync();
                    StateHasChanged();
                });

                return;
            }

            InvokeAsync(async () =>
            {
                await LoadInboxAsync();
                StateHasChanged();
            });
        }
        catch (Exception ex)
        {
            Logger.LineWarning($"[StaffInbox] Không xử lý được sự kiện hộp thư thay đổi: {ex.GetType().Name}");
        }
    }

    /// <summary>
    /// Kiểm tra người gửi có phải nhân viên không (dựa trên loại người gửi).
    /// </summary>
    private static bool IsStaffSender(ChatEnvelope chat)
    {
        var kind = (chat.FromKind ?? string.Empty).Trim().ToLowerInvariant();

        return kind is "staff" or "admin" or "doctor";
    }

    // ---------------------------------------------------------------------
    // Dữ liệu
    // ---------------------------------------------------------------------

    /// <summary>Tải danh sách hộp thư (mới nhất lên đầu).</summary>
    private async Task LoadInboxAsync()
    {
        loading = true;
        StateHasChanged();

        try
        {
            var result = await ChatClient.GetInboxAsync();

            if (!result.IsSuccess)
            {
                error = "Không tải được danh sách hộp thư.";
                Logger.LineWarning($"[StaffInbox] GetInboxAsync thất bại: {result.Error}");
                return;
            }

            inbox.Clear();
            inbox.AddRange(result.Data ?? Array.Empty<ChatInboxItemDto>());

            // Mở hộp thư đầu tiên nếu chưa chọn hộp thư nào.
            if (selectedCustomerId <= 0 && inbox.Count > 0)
            {
                await SelectThreadAsync(inbox[0]);
            }
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (Exception ex)
        {
            Logger.LineError(ex, $"[StaffInbox] Không tải được danh sách hộp thư: {ex.Message}");
            error = "Không tải được danh sách hộp thư.";
        }
        finally
        {
            loading = false;
            StateHasChanged();
        }
    }

    /// <summary>
    /// Mở hộp thư của 1 khách: vào group realtime, tải lịch sử, đánh dấu đã đọc.
    /// </summary>
    private async Task SelectThreadAsync(ChatInboxItemDto item)
    {
        if (item is null || item.CustomerId <= 0)
        {
            return;
        }

        var previousCustomerId = selectedCustomerId;

        selectedCustomerId = item.CustomerId;
        typingIndicator = null;
        presenceOnline = false;

        // Rời hộp thư cũ.
        if (previousCustomerId > 0 && previousCustomerId != selectedCustomerId)
        {
            await Realtime.LeaveInboxAsync(previousCustomerId);
        }

        // Vào hộp thư mới ⇒ nhận tin của đúng khách này (kể cả tin nhân viên
        // KHÁC gửi — hộp thư là chung).
        await Realtime.JoinInboxAsync(selectedCustomerId);

        await LoadThreadAsync();

        // Đánh dấu đã đọc ⇒ badge của hộp thư này về 0.
        await MarkAsReadAsync(selectedCustomerId);

        await ScrollToBottomAsync();
    }

    /// <summary>Tải lịch sử tin nhắn của hộp thư đang mở.</summary>
    private async Task LoadThreadAsync()
    {
        if (selectedCustomerId <= 0)
        {
            return;
        }

        threadLoading = true;
        StateHasChanged();

        try
        {
            var result = await ChatClient.GetHistoryAsync(selectedCustomerId, ChatRepositoryKind.Customer);

            if (!result.IsSuccess)
            {
                error = "Không tải được lịch sử tin nhắn.";
                Logger.LineWarning($"[StaffInbox] GetHistoryAsync thất bại: {result.Error}");
                return;
            }

            messages.Clear();

            foreach (var message in result.Data ?? Array.Empty<ChatMessageDto>())
            {
                messages.Add(new ChatTurn(
                    message.Message,
                    string.IsNullOrWhiteSpace(message.SenderName)
                        ? (message.IsMine ? CurrentUserDisplayName : "Khách hàng")
                        : message.SenderName,
                    string.IsNullOrWhiteSpace(message.SenderRole)
                        ? (message.IsMine ? CurrentRole : "customer")
                        : message.SenderRole,
                    message.IsMine,
                    message.CreatedAt,
                    NextSequence(),
                    message.Id));
            }

            TrimMessages();
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (Exception ex)
        {
            Logger.LineError(ex, $"[StaffInbox] Không tải được lịch sử tin nhắn: {ex.Message}");
            error = "Không tải được lịch sử tin nhắn.";
        }
        finally
        {
            threadLoading = false;
            StateHasChanged();
        }
    }

    /// <summary>
    /// Đánh dấu hộp thư của khách là đã đọc (cập nhật badge trong danh sách).
    /// </summary>
    private async Task MarkAsReadAsync(int customerId)
    {
        try
        {
            var result = await ChatClient.MarkAsReadAsync(customerId);

            if (!result.IsSuccess)
            {
                Logger.LineWarning($"[StaffInbox] MarkAsReadAsync thất bại: {result.Error}");
                return;
            }

            var index = inbox.FindIndex(i => i.CustomerId == customerId);

            if (index >= 0)
            {
                inbox[index] = inbox[index] with { UnreadCount = 0, HasUnread = false };
            }
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (Exception ex)
        {
            Logger.LineWarning($"[StaffInbox] Không đánh dấu đã đọc được hộp thư {customerId}: {ex.GetType().Name}");
        }
    }

    /// <summary>
    /// Cập nhật nhanh tin cuối cùng + số chưa đọc của 1 hộp thư (không tải lại
    /// toàn bộ danh sách).
    /// </summary>
    private void UpdateInboxPreview(int customerId, string message, DateTime sentAt, bool isFromCustomer)
    {
        var index = inbox.FindIndex(i => i.CustomerId == customerId);

        if (index < 0)
        {
            // Hộp thư mới (khách vừa nhắn lần đầu) ⇒ cần tải lại danh sách.
            _ = InvokeAsync(async () =>
            {
                await LoadInboxAsync();
                StateHasChanged();
            });

            return;
        }

        var item = inbox[index];

        inbox[index] = item with
        {
            LastMessage = message,
            LastMessageAt = sentAt,
            LastMessageIsMine = !isFromCustomer,
            UnreadCount = isFromCustomer && customerId != selectedCustomerId
                ? item.UnreadCount + 1
                : item.UnreadCount,
            HasUnread = isFromCustomer && customerId != selectedCustomerId
                ? true
                : item.HasUnread
        };
    }

    // ---------------------------------------------------------------------
    // Tương tác
    // ---------------------------------------------------------------------

    /// <summary>Tải lại danh sách hộp thư (nút làm mới).</summary>
    private async Task RefreshAsync()
    {
        await LoadInboxAsync();
    }

    /// <summary>Lọc danh sách hộp thư theo từ khoá.</summary>
    private void OnSearchChanged(ChangeEventArgs args)
    {
        searchText = args.Value?.ToString() ?? string.Empty;
    }

    /// <summary>Cập nhật nội dung ô nhập + báo "đang gõ".</summary>
    private void OnInputChanged(ChangeEventArgs args)
    {
        draft = args.Value?.ToString() ?? string.Empty;

        _ = NotifyTypingAsync();
    }

    /// <summary>Gửi tin khi nhấn Enter (Shift+Enter không gửi).</summary>
    private async Task OnKeyDownAsync(KeyboardEventArgs args)
    {
        if (args.Key == "Enter" && !args.ShiftKey)
        {
            await SendAsync();
        }
    }

    /// <summary>
    /// Báo trạng thái "đang gõ" (debounce 2 giây) ⇒ khách thấy nhân viên đang gõ.
    /// </summary>
    private async Task NotifyTypingAsync()
    {
        if (selectedCustomerId <= 0)
        {
            return;
        }

        try
        {
            typingCts?.Cancel();
            typingCts?.Dispose();
            typingCts = new CancellationTokenSource();

            await Realtime.SendTypingAsync(selectedCustomerId, true);

            var token = typingCts.Token;
            var customerId = selectedCustomerId;

            _ = Task.Delay(TimeSpan.FromSeconds(2), token).ContinueWith(
                async _ =>
                {
                    try
                    {
                        await Realtime.SendTypingAsync(customerId, false);
                    }
                    catch (Exception ex)
                    {
                        Logger.LineWarning($"[StaffInbox] Không gửi được trạng thái dừng gõ: {ex.GetType().Name}");
                    }
                },
                TaskScheduler.Default);
        }
        catch (Exception ex)
        {
            Logger.LineWarning($"[StaffInbox] Không gửi được trạng thái đang gõ: {ex.GetType().Name}");
        }
    }

    /// <summary>
    /// Gửi tin nhắn cho khách (ghi DB + đẩy realtime).
    /// </summary>
    private async Task SendAsync()
    {
        var text = (draft ?? string.Empty).Trim();

        if (text.Length == 0 || sending || selectedCustomerId <= 0)
        {
            return;
        }

        sending = true;
        error = null;
        draft = string.Empty;

        // Tin "optimistic" — hiện ngay để UX mượt.
        var optimistic = new ChatTurn(
            text,
            CurrentUserDisplayName,
            CurrentRole,
            true,
            DateTime.Now,
            NextSequence());

        messages.Add(optimistic);
        TrimMessages();
        StateHasChanged();
        await ScrollToBottomAsync();

        try
        {
            var result = await ChatClient.SendMessageAsync(new ChatSendRequestDto(
                selectedCustomerId,
                text,
                ChatRepositoryKind.Customer));

            if (!result.IsSuccess)
            {
                error = "Không gửi được tin nhắn.";
                Logger.LineWarning($"[StaffInbox] SendMessageAsync thất bại: {result.Error}");
                return;
            }

            var sent = result.Data?.Message;

            // Thay bản optimistic bằng bản có id thật (tránh hiện 2 bubble).
            if (sent is not null)
            {
                var index = messages.IndexOf(optimistic);

                if (index >= 0)
                {
                    messages[index] = optimistic with
                    {
                        Content = sent.Message,
                        Timestamp = sent.CreatedAt,
                        ExternalId = sent.Id
                    };
                }
                else if (!messages.Any(m => m.ExternalId == sent.Id))
                {
                    messages.Add(optimistic with
                    {
                        Content = sent.Message,
                        Timestamp = sent.CreatedAt,
                        ExternalId = sent.Id
                    });
                }
            }
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (Exception ex)
        {
            Logger.LineError(ex, $"[StaffInbox] Lỗi khi gửi tin nhắn: {ex.Message}");
            error = "Không gửi được tin nhắn.";
        }
        finally
        {
            sending = false;
            StateHasChanged();
        }
    }

    /// <summary>Cuộn khung tin nhắn xuống đáy.</summary>
    private async Task ScrollToBottomAsync()
    {
        try
        {
            await JS.InvokeVoidAsync("chatWidget.scrollToBottom", MessagesBoxId);
        }
        catch (JSException)
        {
            // Prerender / circuit chưa sẵn sàng ⇒ bỏ qua.
        }
        catch (InvalidOperationException)
        {
            // JS interop chưa sẵn sàng (render mode) ⇒ bỏ qua.
        }
    }

    // ---------------------------------------------------------------------
    // Thuộc tính phục vụ hiển thị
    // ---------------------------------------------------------------------

    /// <summary>Sinh số thứ tự để sắp xếp tin nhắn.</summary>
    private long sequenceCounter;

    private long NextSequence() => ++sequenceCounter;

    /// <summary>Giới hạn số tin nhắn giữ trong RAM của circuit.</summary>
    private void TrimMessages()
    {
        if (messages.Count > MaxMessages)
        {
            messages.RemoveRange(0, messages.Count - MaxMessages);
        }
    }

    /// <summary>Nhãn vai trò của người gửi.</summary>
    private static string RoleLabel(string? role) => (role ?? string.Empty).Trim().ToLowerInvariant() switch
    {
        "doctor" => "Bác sĩ",
        "admin" => "Quản trị",
        "staff" => "Nhân viên",
        "customer" or "user" => "Khách hàng",
        _ => "Nhân viên"
    };

    /// <summary>Định dạng thời gian tương đối cho tin nhắn.</summary>
    private static string FormatTime(DateTime? createdAt)
    {
        if (createdAt is null || createdAt == default)
        {
            return string.Empty;
        }

        var diff = DateTime.Now - createdAt.Value;

        if (diff.TotalMinutes < 1) return "Vừa xong";
        if (diff.TotalHours < 1) return $"{Math.Floor(diff.TotalMinutes)} phút";
        if (diff.TotalDays < 1) return $"{Math.Floor(diff.TotalHours)} giờ";
        return createdAt.Value.ToString("dd/MM HH:mm");
    }

    /// <summary>Rút gọn nội dung tin nhắn cuối cho danh sách.</summary>
    private static string Preview(string? message)
    {
        var text = (message ?? string.Empty).Trim();

        if (text.Length == 0)
        {
            return "(trống)";
        }

        return text.Length <= 60 ? text : text[..60] + "…";
    }

    // ---------------------------------------------------------------------
    // Dispose
    // ---------------------------------------------------------------------

    public void Dispose()
    {
        Realtime.ChatReceived -= HandleChatReceived;
        Realtime.ChatTypingReceived -= HandleTypingReceived;
        Realtime.ChatPresenceReceived -= HandlePresenceReceived;
        Realtime.ChatInboxChanged -= HandleInboxChanged;

        try
        {
            typingCts?.Cancel();
            typingCts?.Dispose();
        }
        catch (ObjectDisposedException)
        {
            // Đã dispose rồi.
        }

        typingCts = null;
    }

    /// <summary>
    /// Giải phóng khi component bị huỷ.
    ///
    /// <para>
    /// KHÔNG ngắt kết nối SignalR ở đây vì <c>RealtimeHubService</c> dùng CHUNG
    /// cho cả chuông + widget chat + trang này (1 WebSocket mỗi circuit).
    /// </para>
    /// </summary>
    public ValueTask DisposeAsync()
    {
        Dispose();
        return ValueTask.CompletedTask;
    }

    /// <summary>
    /// Một lượt tin nhắn trong khung chat của trang Inbox.
    /// </summary>
    private sealed record ChatTurn(
        string Content,
        string SenderName,
        string SenderRole,
        bool IsMine,
        DateTime Timestamp,
        long Sequence,
        int ExternalId = 0);
}
