namespace PetShop.Services;

public sealed class StaffActionFeedback(ILogger<StaffActionFeedback> logger)
{
    public event Action? Changed;
    public string Message { get; private set; } = string.Empty;
    public bool IsError { get; private set; }
    public long Version { get; private set; }
    public void Show(string message, bool error = false)
    {
        Version++;
        Message = message;
        IsError = error;
        Changed?.Invoke();
    }
    public async Task<bool> RunAsync(Func<Task<bool>> action, string success, bool destructive = false)
    {
        try
        {
            var ok = await action();
            Show(ok ? success : "Thao tác chưa thành công. Vui lòng thử lại.", !ok || destructive);
            return ok;
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Thao tác nhân viên thất bại.");
            Show("Không thể hoàn tất thao tác. Vui lòng thử lại.", true);
            return false;
        }
    }
}
