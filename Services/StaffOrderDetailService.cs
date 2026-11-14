using Microsoft.EntityFrameworkCore;
using PetShop.Data;

namespace PetShop.Services;

public sealed record StaffOrderLine(string Name, int Quantity, decimal Price, string? ImageUrl);
public sealed record StaffOrderDetail(string Customer, string Phone, string Email, string Address, string PaymentMethod, string PaymentStatus, DateTime? PaidAt, List<StaffOrderLine> Items, string? Note);

public sealed class StaffOrderDetailService(IDbContextFactory<ShopPetDatabaseContext> factory)
{
    public async Task<StaffOrderDetail?> GetAsync(int id)
    {
        await using var db = await factory.CreateDbContextAsync();
        var order = await db.Orders.AsNoTracking().Where(o => o.OrderId == id)
            .Select(o => new { o.CustomerId, o.ShippingAddress, o.PaymentMethod, o.PaymentStatus, o.PaidAt, o.CustomerNote,
                Items = o.OrderDetails.Select(d => new StaffOrderLine(d.Product != null ? d.Product.Name : "Dịch vụ #" + d.ServiceId, d.Quantity ?? 1, d.UnitPrice ?? 0, d.Product != null ? d.Product.ImageUrl : null)).ToList() }).SingleOrDefaultAsync();
        if (order is null) return null;
        var customer = await db.Customers.AsNoTracking().Where(c => c.CustomerId == order.CustomerId)
            .Select(c => new { c.Name, c.Phone, c.Email }).FirstOrDefaultAsync();
        return new(customer?.Name ?? "Khách lẻ", customer?.Phone ?? "Chưa cung cấp", customer?.Email ?? "Chưa cung cấp", order.ShippingAddress ?? "Chưa có địa chỉ giao hàng", order.PaymentMethod ?? "Chưa ghi nhận", OrderStatusText.Normalize(order.PaymentStatus), order.PaidAt, order.Items, order.CustomerNote);
    }
}
