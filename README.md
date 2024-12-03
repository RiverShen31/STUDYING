### PE Infector
1 virus lây nhiễm file PE x86 sử dụng kỹ thuật delta:
* Chèn code virus vào file muốn lây nhiễm
* Chuyển EntryPoint (địa chỉ lệnh đầu tiên của file được thực hiện) đến vùng code thực thi của virus
* Sau khi thực thi code virus xong, trả quyền điều khiển về cho host (file gốc)

### Build
- Được viết bằng MASM
- Thực hiện build bằng MASM32 Editor

### Cách lây nhiễm
- Chạy thực thi lây nhiễm trong folder (In ra message box, không chứa các đoạn mã độc)
- Các file exe đã bị lây nhiễm sẽ tiếp tục lây nhiễm các file khác nếu được thực thi.