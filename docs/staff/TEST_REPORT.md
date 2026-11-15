# Báo cáo kiểm thử Staff — 14/11/2026

## Kết luận
66 kiểm tra nghiệp vụ pass trên SQL Server LocalDB thật và HTTP thật tới localhost:5286. Không phải 66 kịch bản UI đầu-cuối độc lập: nhiều kiểm tra là các bước/assertion trong cùng luồng. 13/13 test hồi quy pass (7 biên giờ check-in, 6 chuẩn hóa trạng thái). Chưa thể tuyên bố toàn bộ sản phẩm đã pass.

## Ma trận đã thực hiện
| Nhóm | Thao tác và dữ liệu đối chiếu | Kết quả |
|---|---|---|
| Tài khoản phục vụ test | Khách và hai staff đăng nhập HTTP; email phân giải staff_id; đọc và lưu lại hồ sơ không đổi giá trị | PASS |
| Sản phẩm | Tạo, đổi tên, lấy lại, xóa mềm, kiểm tra không xuất hiện danh sách active, khôi phục | PASS |
| Tồn kho | Cộng 1,2,3,5,10,100; đọc DB sau mỗi lần; từ chối 0/âm; 5 lần cộng đồng thời | PASS |
| Đơn hàng | Khách tạo COD; xuất hiện danh sách staff; giá lấy DB thay vì giá giả 1đ của client; địa chỉ/note/dòng hàng đúng | PASS |
| Xử lý đơn | Chờ xác nhận → đóng gói → giao → hoàn thành; kho giảm đúng 2 | PASS |
| Idempotency | Gọi đóng gói/hoàn thành/hủy lặp không trừ/hoàn kho hai lần; chặn quay trạng thái lùi | PASS |
| Hủy và thiếu kho | Hủy trước xác nhận, hủy sau đóng gói hoàn kho; thiếu kho không xác nhận và giữ trạng thái | PASS |
| Seed cũ | Xác nhận/hủy đơn có trạng thái lỗi UTF-8 trước đây | PASS |
| Ghi chú | Ghi chú tiếng Việt được gửi/lưu/đọc bởi staff; ghi chú rỗng lưu null | PASS |
| Lịch dịch vụ | Khách đặt tiền mặt; mới tạo vẫn Chưa thanh toán; khách và staff thấy; nhận → hoàn thành | PASS |
| Đổi ca | Gửi, từ chối, người gửi hủy, sai người không duyệt được, đúng người chấp nhận; hai chủ ca đổi trong DB | PASS |
| Chấm công | Chặn ca tương lai/quá giờ; ca hiện tại ghi timestamp, IsLate; gọi lặp chỉ một AttendanceRecord | PASS |
| Tổng quan | Service dashboard/doanh thu đọc thành công trên dữ liệu thật | PASS |

Bằng chứng chi tiết: `staff-flow-results-2026-11-14.txt`. Đã tạo dữ liệu QA riêng, không chuyển trạng thái đơn của người dùng. ProductId cuối=48; các đơn/lịch QA còn giữ để đối chiếu và sẽ ảnh hưởng thống kê local. Bản ghi chấm công thử vừa tạo đã dọn. Các lượt chạy trước cũng để lại QA; không xóa dữ liệu khác tự động.

## Kiểm thử tự động chung
Lệnh chạy: `dotnet test tests/PetShop.Tests/PetShop.Tests.csproj --filter "FullyQualifiedName!~ForgotPasswordFlowTests"` (dùng OutputPath riêng để tránh khóa app đang chạy).
Trước khi thêm 6 test chuẩn hóa trạng thái: 269 pass / 3 fail / 272 tổng. Sau đó chạy riêng 13 test mới: 13 pass.
Ba fail cùng nhóm RamOptimizationGuardTests: ScriptOptimizeAnh_TonTaiVaChayDuoc, AnhTrongWwwroot_KhongVuotChieuRong1400Px, DirectoryBuildProps_TatMSBuildNodeReuseVaSharedCompilation. Không sửa các phần tối ưu RAM/asset trong nhánh staff.
Build trực tiếp bản clone nhánh hung: 0 error, 1 warning CS1998 có sẵn ở ChatbotService.cs:1535.

## Chưa xác minh
- Click thực tế qua trình duyệt: responsive/mobile, modal, upload ảnh, logout và 3 giây toast.
- PayOS QR/webhook thật: cấu hình local chưa đủ; không giả lập thanh toán thành công.
- Tính lương/checkout đầy đủ và xử lý ngoại lệ nhân sự.
- Stress test nhiều người cùng check-in/duyệt đổi ca. Test tồn kho đồng thời không chứng minh toàn bộ luồng concurrency.
- ForgotPasswordFlowTests ngoài phạm vi staff không chạy.

## Phạm vi commit và schema
Giữ thay đổi staff, UI dùng chung của staff và phần nối ghi chú checkout để staff đọc được. Không đưa sửa SpaCart/SpaBookingRepository phía khách, file SQL dump, dữ liệu DB, appsettings, log local hay demo seed vào commit.
Chạy `Scripts/2026-11-14_order_customer_note.sql` trên DB leader trước khi chạy code (đổi USE nếu DB tên khác). Script nullable và kiểm tra tồn tại cột, không xóa dữ liệu. `2026-11-14_local_staff_compatibility.sql` dành cho SQL cũ thiếu avatar_url/birth_date. Không import lại seed chồng lên database đang dùng.
