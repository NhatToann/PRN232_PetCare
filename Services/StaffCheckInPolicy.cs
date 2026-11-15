namespace PetShop.Services;

public static class StaffCheckInPolicy
{
    public static string? Validate(DateTime start, DateTime end, DateTime now)
    {
        if (now >= end) return "Ca đã kết thúc. Không thể check-in sau giờ kết thúc ca.";
        if (now < start.AddMinutes(-15)) return "Chưa đến giờ check-in. Bạn có thể check-in từ 15 phút trước ca.";
        return null;
    }
}
