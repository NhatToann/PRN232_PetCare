# Hướng dẫn ôn phần Staff — Hưng

## Cách trình bày với thầy
Đây là .NET 8 Blazor Interactive Server. UI gọi service, service làm nghiệp vụ và gọi repository, repository dùng EF Core với SQL Server. Một số phần gọi chính API của app qua HttpClient. Không phải mỗi màn hình đều gọi controller: ví dụ ProductInventory gọi IProductManagementService trực tiếp.

## Bản đồ file/class cần học
| Chức năng | UI | Service / Interface | Repository / dữ liệu |
|---|---|---|---|
| Dashboard | Components/Pages/StaffDashboard.razor | StaffReportsService / IStaffReportsService | StaffReportsRepository / IStaffReportsRepository; Models/StaffReportDtos.cs |
| Doanh thu | Components/Pages/Revenue.razor | StaffReportsService.GetRevenueSummaryAsync | Đơn hàng, Booking, Payment; chỉ dùng dữ liệu thật |
| Đơn hàng | Components/Pages/StaffOrders.razor | StaffReportsService.GetOrderListAsync/UpdateOrderStatusAsync; StaffOrderDetailService.GetAsync | StaffReportsRepository; Models/Order.cs, OrderDetail.cs; StaffOrderLine, StaffOrderDetail |
| Sản phẩm | ProductList, ProductCreate, ProductEdit, ProductDeleted.razor | ProductManagementService / IProductManagementService | ProductManagementRepository / IProductManagementRepository; Product |
| Tồn kho | ProductInventory.razor | IncreaseStockAsync | ExecuteUpdateAsync cộng nguyên tử; kiểm quantity > 0 và không tràn int |
| Lịch hẹn | StaffBookings.razor | StaffReportsService.GetBookingListAsync/UpdateBookingStatusAsync | Booking, BookingService, Pet, Breed, Customer |
| Lịch trực/check-in | StaffSchedule.razor | StaffDashboardService / IStaffDashboardService; StaffCheckInPolicy | WorkSchedule, AttendanceRecord, WorkScheduleDedup |
| Đổi ca | Components/Staff/ShiftSwapPanel.razor | gọi api/shift-exchange; NotificationClient / INotificationClient | ShiftExchangeController.cs, .Requests.cs, .Processing.cs; ShiftRequests |
| Duyệt và thông báo | NotificationBell.razor/.razor.cs | NotificationClient, RealtimeHubService; StaffProfileService phân giải staff_id | API pending/accept/decline/cancel; SignalR |
| Hồ sơ | StaffProfile.razor | StaffProfileService / IStaffProfileService | Định vị theo email trước để không nhầm CustomerId và StaffId |
| Layout | StaffWorkspaceLayout.razor/.css | UserSessionService, StaffRefreshSignal | Sidebar, breadcrumb, refresh, guard, avatar; Logout.razor |
| Phản hồi | StaffActionNotice.razor | StaffActionFeedback | Thông báo 3s + 0,5s fade, hủy timer cũ khi có thông báo mới |
| Chuẩn hóa seed | — | OrderStatusText | Decode chuỗi lỗi mã hóa, thống nhất hủy/huỷ; dùng trước khi chuyển trạng thái |
| Đồ họa | wwwroot/css/staff-dashboard.css; wwwroot/js/staffDashboard.js | Chart.js có sẵn | 7 ngày và tỷ trọng dùng dữ liệu service |
| DI | Program.cs | AddScoped/DbContextFactory | Đăng ký service/repository theo scope |

Các file/class cũ có sẵn trong repo vẫn cần hiểu để trả lời review; không phải tất cả trong bảng do Hưng viết mới.

## Luồng mẫu nên thuộc
1. Khách COD: Checkout.razor.cs → FrontendCheckoutRequest → CheckoutClient → CheckoutController → tạo Order/OrderDetails; giá đọc DB, ghi note vào customer_note. Chưa trừ kho khi mới tạo đơn.
2. Staff đọc: StaffOrders → StaffReportsService → StaffReportsRepository.GetRecentOrdersAsync. OrderBy trước Take, màn staff lấy toàn bộ dữ liệu để lọc không bỏ sót đơn mới.
3. Bấm dòng: StaffOrderDetailService.GetAsync projection khách/địa chỉ/thanh toán/items và note. Không có note hiển thị Không có.
4. Xác nhận: UpdateOrderStatusAsync dùng transaction Serializable. Chờ xác nhận → Đang đóng gói trừ kho có điều kiện đủ hàng. Nếu bất kỳ dòng nào không đủ thì rollback cả đơn. Trạng thái sau chỉ cập nhật khi thành công.
5. Hủy lúc chờ chưa trừ kho; hủy sau đóng gói hoàn lại kho. Gọi lặp cùng trạng thái không trừ/hoàn lại. Không cho đơn hoàn thành quay lùi.
6. Check-in: ResolveStaffIdAsync → lấy đúng lịch theo ScheduleId → StaffCheckInPolicy (trước ca tối đa 15 phút, từ giờ kết thúc từ chối) → AttendanceRecord timestamp/IsLate + mã CheckedIn trong cùng SaveChanges. UI biết dữ liệu cũ Đ/Ð và cập nhật đồng hồ mỗi giây.
7. Đổi ca: chọn hai ScheduleId thuộc hai nhân viên → create swap Pending → người nhận đọc pending → accept kiểm chủ ca, ngày tương lai, chưa chấm công, trùng giờ → hoán đổi StaffId → Approved → thông báo realtime. Có từ chối/hủy.

## Câu hỏi thường gặp
- Vì sao DbContextFactory? Mỗi thao tác một context, tránh layout/page Blazor chạy song song dùng cùng context.
- Vì sao AsNoTracking? Truy vấn chỉ đọc không cần theo dõi entity, giảm overhead.
- Vì sao ExecuteUpdateAsync? Cộng/trừ kho ngay trong SQL thay vì đọc số cũ rồi ghi đè, tránh mất cập nhật.
- Vì sao transaction? Đảm bảo trạng thái đơn và tất cả sản phẩm được cập nhật cùng nhau; thiếu một món thì không trừ dở dang.
- Vì sao DTO? Chỉ lấy dữ liệu cần hiển thị, không gửi entity/password cho UI.
- Vì sao cần chuẩn hóa trạng thái? SQL seed cũ lưu lỗi mã hóa, chữ nhìn giống nhưng so sánh không bằng; chỉ sửa ở UI thì backend vẫn từ chối.
- Vì sao truyền Note đến API và thêm cột? Trước đó form có ô note nhưng request/DB không lưu, staff không thể đọc lại.
- Tiền mặt có nghĩa đã thanh toán? Không; chỉ là phương thức. Khi mới đặt lịch vẫn Chưa thanh toán.
- Phần nào chưa hoàn thiện? Xem TEST_REPORT.md; không khẳng định mọi nghiệp vụ nhân sự/PayOS/UI đều đã pass.

## Chuẩn bị demo
Dùng database local đã cập nhật schema. Đăng nhập staff A/B, tạo sản phẩm riêng, thử nhập 5, đặt một COD từ khách, mở chi tiết, xác nhận và xem tồn kho; hủy một đơn khác để thấy hoàn kho. Tạo hai lịch tương lai chưa check-in trước khi demo đổi ca. Không check-in ca tương lai để làm đẹp demo: hệ thống phải từ chối.
Không đọc/đưa secret lên màn hình khi thầy review. Không merge main trước khi leader xem diff.
