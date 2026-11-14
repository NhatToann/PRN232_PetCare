using System.Text;

namespace PetShop.Services;

public static class OrderStatusText
{
    public static string Normalize(string? value)
    {
        var text = value ?? string.Empty;
        Encoding.RegisterProvider(CodePagesEncodingProvider.Instance);
        var legacy = Encoding.GetEncoding(1252, EncoderFallback.ExceptionFallback, DecoderFallback.ExceptionFallback);
        var utf8 = new UTF8Encoding(false, true);
        for (var i = 0; i < 3 && (text.Contains("Ã") || text.Contains("áº") || text.Contains("á»") || text.Contains("Ä")); i++)
        {
            try { text = utf8.GetString(legacy.GetBytes(text)); }
            catch (EncoderFallbackException) { break; }
            catch (DecoderFallbackException) { break; }
        }
        return text.Trim().Replace('Ð', 'Đ').Replace("Đã huỷ", "Đã hủy").Replace("Đã hoàn tất", "Hoàn thành");
    }
}
