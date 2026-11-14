using PetShop.Services;

namespace PetShop.Tests;

public class OrderStatusTextTests
{
    [Theory]
    [InlineData("Chá» xÃ¡c nháº­n", "Chờ xác nhận")]
    [InlineData("Đã huỷ", "Đã hủy")]
    [InlineData("Ðã Check-in", "Đã Check-in")]
    [InlineData("Đã hoàn tất", "Hoàn thành")]
    [InlineData(" Chờ xác nhận ", "Chờ xác nhận")]
    [InlineData(null, "")]
    public void Normalize_LegacyAndCurrentValues(string? input, string expected)
    {
        Assert.Equal(expected, OrderStatusText.Normalize(input));
    }
}
