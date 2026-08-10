# Phiếu Phản Ánh — K3 Ngày 12

**Họ và tên:** Nguyễn Thế Anh
**Mã học viên:** 2A202601791

---

### Câu 1 — Fail fast (CP1)

Một tình huống cụ thể là khi tôi deploy app lên server nhưng quên cấu hình biến môi trường `agent_api_key`. Nếu có mặc định `"changeme"` thì app vẫn khởi động bình thường, nhưng khi người dùng gọi API thì mới phát hiện API key không hợp lệ. Việc này làm tôi mất thời gian tìm lỗi. Nếu không có giá trị mặc định, app sẽ dừng ngay lúc khởi động và báo thiếu `agent_api_key`, nhờ đó tôi biết ngay cần bổ sung biến môi trường trước khi deploy.

---

### Câu 2 — Log cho máy đọc (CP1)

Một dòng log JSON tôi có thể thu được có dạng:

```json
{"method":"POST","path":"/ask","status":200,"user_id":"user01","latency_ms":1250}
```

Từ dòng log này, tôi có thể biết được **request nào mất nhiều thời gian xử lý** thông qua `latency_ms`, và có thể **lọc/thống kê số request theo user, endpoint hoặc status code**.

Trong khi đó, `print("đã trả lời xong")` chỉ cho biết chương trình đã chạy đến đó, không có cấu trúc để máy dễ dàng lọc, tìm kiếm hoặc thống kê.

---

### Câu 3 — Kích thước image (CP2)

Sau khi build hai phiên bản, tôi ghi lại dung lượng thực tế bằng lệnh `docker images | grep agent`.

| Bản               | Dung lượng |
| ----------------- | ---------: |
| 1 stage (bản đầu) | **1.02 GB** |
| Multi-stage       | **195MB** |

Phần dung lượng chênh lệch chủ yếu đến từ các thành phần chỉ cần trong quá trình build như **compiler, package build tools, cache và các file trung gian**. Với multi-stage build, những thành phần này không được đưa sang image cuối cùng, nên image production nhỏ hơn và giảm bề mặt tấn công.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Khi tôi chỉ sửa một ký tự trong `app/main.py`, các layer phía trước phần `COPY app .` vẫn có thể được Docker lấy lại từ cache. Vì vậy các bước như cài dependency bằng `pip install` không cần chạy lại nếu các file dependency không thay đổi. Chỉ những layer từ chỗ `COPY` chứa source code trở xuống phải build lại.

Nếu đặt `COPY . .` trước `RUN pip install`, mỗi lần thay đổi bất kỳ file nào trong project, Docker có thể làm mất cache của layer đó và phải chạy lại `pip install`. Vì vậy cách đặt `COPY` file dependency trước rồi mới `COPY` source code sẽ giúp build nhanh hơn.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Nếu code Python có một lỗ hổng và kẻ tấn công khai thác được lỗ hổng đó, họ có thể thực thi code bên trong container với quyền của user đang chạy ứng dụng. Nếu container chạy bằng `root`, kẻ tấn công sẽ có quyền rất cao trong container và nếu kết hợp với một lỗ hổng container hoặc cấu hình Docker không an toàn thì nguy cơ ảnh hưởng đến host sẽ lớn hơn.

Lệnh `USER` tạo một user có quyền thấp và cho container chạy bằng user đó. Như vậy ngay cả khi ứng dụng bị khai thác, quyền của kẻ tấn công cũng bị giới hạn, làm giảm khả năng leo thang đặc quyền.

---

### Câu 6 — Cửa sổ trượt (CP3)

Nếu dùng cách đếm theo phút đồng hồ và giới hạn là **10 request/phút**, người dùng có thể gửi tối đa **20 request trong khoảng 2 giây**.

Ví dụ, người dùng gửi 10 request ngay trước thời điểm chuyển sang phút mới, chẳng hạn lúc `12:59:59`, sau đó gửi tiếp 10 request ngay lúc `13:00:00`. Hai nhóm request thuộc hai phút khác nhau nên đều được chấp nhận.

Đây là lý do sliding window tốt hơn vì nó tính request trong **60 giây gần nhất**, thay vì phụ thuộc vào thời điểm giây `00`.

---

### Câu 7 — Rate limit và cost guard (CP3)

Rate limit giới hạn **số lượng request**, còn cost guard kiểm soát **chi phí/tài nguyên tiêu thụ** của request.

Ví dụ rate limit có thể cho phép 10 request/phút. Một người dùng gửi 10 request nhưng mỗi request yêu cầu AI xử lý một lượng token rất lớn, làm chi phí vượt giới hạn. Khi đó rate limit vẫn cho qua nhưng cost guard phải chặn.

Ngược lại, một request có thể sử dụng rất ít token nên chi phí thấp, nhưng người dùng gửi hàng nghìn request trong thời gian ngắn. Khi đó cost guard có thể chưa vượt ngưỡng nhưng rate limit phải chặn để tránh spam hoặc quá tải hệ thống.

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp `/health` và `/ready` thành một endpoint và endpoint đó kiểm tra Redis, khi Redis mất kết nối thì container sẽ lần lượt bị coi là không khỏe/không sẵn sàng.

Với cụm 3 container, cả 3 container đều có thể trả trạng thái lỗi vì đều không kết nối được Redis. Orchestrator hoặc hệ thống deploy sẽ thấy health check thất bại và có thể restart các container. Trong thời gian Redis mất 30 giây, việc restart liên tục có thể khiến cả 3 container cùng bị ảnh hưởng, mặc dù bản thân ứng dụng vẫn có thể đang chạy.

Tách `/health` và `/ready` giúp phân biệt: app còn sống hay không và app đã sẵn sàng nhận traffic hay chưa.

---

### Câu 9 — Stateless (CP4)

Khi chạy 3 container, mỗi container có một bộ nhớ Python riêng. Nếu lịch sử được lưu trong một `dict` Python thì mỗi container chỉ biết lịch sử của những request đã được xử lý bởi chính container đó.

Vì vậy khi tôi gọi `/ask` nhiều lần với cùng `X-User-Id`, `history_length` sẽ không tăng đều theo tất cả request. Ví dụ request đầu tiên vào container A thì lịch sử ở A tăng, nhưng request tiếp theo được load balance sang container B thì B không biết lịch sử ở A và có thể bắt đầu lại từ `0` hoặc một giá trị thấp hơn.

Nếu lưu lịch sử trong Redis thì cả 3 container cùng đọc và ghi vào một nơi dùng chung, nên `history_length` sẽ tăng nhất quán dù request được chuyển đến container nào.

---

### Câu 10 — Deploy thật (CP5)
### URL: https://day12-agent-vf6z.onrender.com
Một lỗi tôi gặp khi deploy là ứng dụng không chạy đúng trên cloud vì server yêu cầu ứng dụng phải lắng nghe port được truyền qua biến môi trường `$PORT`. Ban đầu ứng dụng của tôi sử dụng port cố định nên health check không kết nối được.

Tôi kiểm tra log deploy và thấy ứng dụng đã start nhưng health check bị timeout. Sau đó tôi kiểm tra lại cấu hình chạy server và nhận ra app chưa đọc biến `$PORT`. Tôi sửa code để lấy port từ biến môi trường, đồng thời đặt giá trị mặc định khi chạy local. Sau khi deploy lại, ứng dụng lắng nghe đúng port mà cloud cung cấp và health check hoạt động bình thường.
