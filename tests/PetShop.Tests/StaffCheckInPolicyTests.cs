using PetShop.Services;

namespace PetShop.Tests;

public class StaffCheckInPolicyTests
{
    [Theory]
    [InlineData(7, 44, false)]
    [InlineData(7, 45, true)]
    [InlineData(8, 0, true)]
    [InlineData(16, 59, true)]
    [InlineData(17, 0, false)]
    [InlineData(17, 1, false)]
    public void CheckInWindow_UsesShiftBoundaries(int hour, int minute, bool allowed)
    {
        var day = new DateTime(2026, 11, 14);
        Assert.Equal(allowed, StaffCheckInPolicy.Validate(day.AddHours(8), day.AddHours(17), day.AddHours(hour).AddMinutes(minute)) is null);
    }

    [Fact]
    public void FutureShift_CannotCheckIn()
    {
        var day = new DateTime(2026, 11, 14);
        Assert.NotNull(StaffCheckInPolicy.Validate(day.AddDays(1).AddHours(8), day.AddDays(1).AddHours(17), day.AddHours(8)));
    }
}
