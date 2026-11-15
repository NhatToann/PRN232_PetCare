using Microsoft.AspNetCore.SignalR;
using Microsoft.AspNetCore.SignalR.Client;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.AspNetCore.Mvc.Testing;
using PetShop.Hubs;
using PetShop.Models;

namespace PetShop.Tests;

/// <summary>
/// Test END-TO-END realtime của luồng chat khách ↔ nhân viên (15/11/2026).
///
/// <para>
/// <b>VÌ SAO CẦN:</b> bug "nhân viên không thấy tin khách nhắn" KHÔNG biểu
/// hiện ở tầng unit test — nó chỉ xuất hiện khi chạy thật SignalR:
/// </para>
/// <list type="number">
///   <item><description>
///     Client phải vào được group <c>chat:staff</c> ⇒ cần truyền <c>role</c>.
///   </description></item>
///   <item><description>
///     Sau khi negotiate, các lệnh hub chạy qua WEBSOCKET ⇒
///     <c>Context.GetHttpContext()</c> = null ⇒ query string <c>?role=</c> không
///     đọc được ⇒ phải CACHE danh tính lúc <c>OnConnectedAsync</c>.
///   </description></item>
///   <item><description>
///     Hộp thư của khách phải vào được group <c>inbox:{customerId}</c>.
///   </description></item>
/// </list>
///
/// <para>
/// Test dựng app thật (TestServer) + client SignalR thật ⇒ bắt được đúng các
/// lỗi trên.
/// </para>
/// </summary>
public sealed class ChatInboxSignalREndToEndTests : IAsyncLifetime
{
    private WebApplicationFactory<Program>? _factory;

    public Task InitializeAsync()
    {
        _factory = new WebApplicationFactory<Program>();

        return Task.CompletedTask;
    }

    public async Task DisposeAsync()
    {
        if (_factory is not null)
        {
            await _factory.DisposeAsync();
        }
    }

    /// <summary>
    /// Dựng client SignalR kết nối tới hub với <c>userId</c> + <c>role</c>
    /// (chế độ LOCAL DEMO của dự án).
    /// </summary>
    private HubConnection CreateHubConnection(int userId, string role)
    {
        var factory = _factory ?? throw new InvalidOperationException("Factory chưa khởi tạo.");

        var url = $"http://localhost/hubs/notification?userId={userId}&role={role}";

        return new HubConnectionBuilder()
            .WithUrl(url, options =>
            {
                options.HttpMessageHandlerFactory = _ => factory.Server.CreateHandler();
            })
            .Build();
    }

    /// <summary>
    /// Nhân viên vào group <c>chat:staff</c> ⇒ khi khách nhắn, nhân viên nhận
    /// được event <c>ChatReceived</c>.
    ///
    /// <para>
    /// Đây chính là kịch bản gây bug "nhân viên không thấy tin khách nhắn".
    /// </para>
    /// </summary>
    [Fact]
    public async Task NhanVien_VaoGroupChatStaff_ThiNhanVienNhanTinCuaKhach()
    {
        const int staffId = 1;
        const int customerId = 50;

        await using var staffConnection = CreateHubConnection(staffId, "staff");
        await using var customerConnection = CreateHubConnection(customerId, "customer");

        var staffReceived = new TaskCompletionSource<ChatEnvelope>(TaskCreationOptions.RunContinuationsAsynchronously);
        staffConnection.On<ChatEnvelope>(NotificationHub.ChatReceivedEvent, e => staffReceived.TrySetResult(e));

        await staffConnection.StartAsync();
        await staffConnection.InvokeAsync("JoinGroup", staffId, "staff");

        await customerConnection.StartAsync();
        await customerConnection.InvokeAsync("JoinGroup", customerId, "customer");

        // Nhân viên vào group staff; khách nhắn ⇒ nhân viên nhận được tin.
        var payload = new ChatEnvelope(
            customerId,
            customerId,
            "Chào shop",
            DateTime.Now,
            IsPersisted: true,
            MessageId: 7001,
            FromKind: "customer",
            ToKind: "customer",
            ToCustomerId: customerId,
            SenderName: "Khách",
            SenderRole: "customer");

        await BroadcastAsync(NotificationHub.StaffGroup, NotificationHub.ChatReceivedEvent, payload);

        var received = await staffReceived.Task.WaitAsync(TimeSpan.FromSeconds(15));

        Assert.Equal(customerId, received.FromUserId);
        Assert.Equal("customer", received.FromKind);
        Assert.Equal("Chào shop", received.Message);
    }

    /// <summary>
    /// Nhân viên mở hộp thư của khách X ⇒ vào group <c>inbox:X</c> ⇒ nhận
    /// được tin của đúng khách đó (kể cả tin nhân viên KHÁC gửi).
    /// </summary>
    [Fact]
    public async Task NhanVien_MoHopThuKhach_ThiNhanTinCuaDungKhachDoDen()
    {
        const int staffId = 1;
        const int customerId = 50;

        await using var staffConnection = CreateHubConnection(staffId, "staff");

        var received = new TaskCompletionSource<ChatEnvelope>(TaskCreationOptions.RunContinuationsAsynchronously);
        staffConnection.On<ChatEnvelope>(NotificationHub.ChatReceivedEvent, e => received.TrySetResult(e));

        await staffConnection.StartAsync();
        await staffConnection.InvokeAsync("JoinGroup", staffId, "staff");

        // ⚠️ Lệnh này chạy qua WEBSOCKET (sau negotiate) ⇒ phải dùng danh tính
        // đã CACHE lúc OnConnectedAsync, không đọc được query string nữa.
        await staffConnection.InvokeAsync("JoinInbox", customerId);

        // Tin của nhân viên KHÁC gửi ⇒ nhân viên đang mở hộp thư thấy.
        var payload = new ChatEnvelope(
            customerId,
            99,
            "Tin từ nhân viên khác",
            DateTime.Now,
            IsPersisted: true,
            MessageId: 7002,
            FromKind: "staff",
            ToKind: "customer",
            ToCustomerId: customerId,
            SenderName: "Nhân viên khác",
            SenderRole: "staff");

        await BroadcastAsync(NotificationHub.InboxGroup(customerId), NotificationHub.ChatReceivedEvent, payload);

        var got = await received.Task.WaitAsync(TimeSpan.FromSeconds(15));

        Assert.Equal(customerId, got.ToCustomerId);
        Assert.Equal("Tin từ nhân viên khác", got.Message);
    }

    /// <summary>
    /// Khách nhận được typing indicator của nhân viên (2 chiều).
    /// </summary>
    [Fact]
    public async Task Khach_NhanDuocTypingIndicator_CuaNhanVien()
    {
        const int staffId = 1;
        const int customerId = 50;

        await using var staffConnection = CreateHubConnection(staffId, "staff");
        await using var customerConnection = CreateHubConnection(customerId, "customer");

        var typingReceived = new TaskCompletionSource<ChatTypingDto>(TaskCreationOptions.RunContinuationsAsynchronously);
        customerConnection.On<ChatTypingDto>(NotificationHub.ChatTypingEvent, t => typingReceived.TrySetResult(t));

        await customerConnection.StartAsync();
        await customerConnection.InvokeAsync("JoinGroup", customerId, "customer");

        await staffConnection.StartAsync();
        await staffConnection.InvokeAsync("JoinGroup", staffId, "staff");

        // Nhân viên báo "đang gõ" trong hộp thư của khách.
        await staffConnection.InvokeAsync("SendTyping", customerId, true);

        var typing = await typingReceived.Task.WaitAsync(TimeSpan.FromSeconds(15));

        Assert.Equal(customerId, typing.CustomerId);
        Assert.True(typing.IsTyping);
    }

    /// <summary>
    /// Khách chỉ được báo typing trong hộp thư CỦA CHÍNH MÌNH.
    /// </summary>
    [Fact]
    public async Task Khach_HongDuocBaoTyping_TrongHopThuCuaKhachKhac()
    {
        const int customerId = 50;
        const int otherCustomerId = 51;

        await using var customerConnection = CreateHubConnection(customerId, "customer");
        await customerConnection.StartAsync();
        await customerConnection.InvokeAsync("JoinGroup", customerId, "customer");

        // Khách 50 cố báo typing trong hộp thư của khách 51 ⇒ phải bị từ chối.
        var ex = await Assert.ThrowsAsync<HubException>(
            () => customerConnection.InvokeAsync("SendTyping", otherCustomerId, true));

        Assert.Contains("hộp thư", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    /// <summary>
    /// Đẩy event tới 1 group qua <see cref="IHubContext{THub}"/> (giống hệt
    /// cách tầng service push realtime).
    /// </summary>
    private async Task BroadcastAsync(string group, string eventName, object payload)
    {
        var factory = _factory ?? throw new InvalidOperationException("Factory chưa khởi tạo.");

        using var scope = factory.Services.CreateScope();

        var hubContext = scope.ServiceProvider.GetRequiredService<IHubContext<NotificationHub>>();

        await hubContext.Clients.Group(group).SendAsync(eventName, payload);
    }
}
