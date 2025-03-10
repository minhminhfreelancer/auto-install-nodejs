# 🚀 Node.js Auto-Deployment System

*[English](#english) | [Tiếng Việt](#tiếng-việt)*

An automated deployment system for Node.js applications with zero-configuration subdomain creation, automatic SSL, database provisioning, and continuous deployment.

Developed by [freelancer.io.vn](https://freelancer.io.vn/)

<a name="english"></a>
## ✨ Features

- **Custom Domain Support**: Use your own domain with wildcard DNS
- **Node.js 20 LTS**: Latest LTS version pre-configured
- **Instant Subdomains**: Automatically creates `yourapp.yourdomain.com`
- **Automatic SSL**: Let's Encrypt SSL certificates with auto-renewal
- **Database Integration**: PostgreSQL database and user for each application
- **Email Configuration**: SMTP account for each application
- **Continuous Deployment**: Auto-updates from Git every 5 seconds
- **Multiple Application Types**: Support for static sites, SPAs, Node.js backends, and fullstack apps
- **Comprehensive Monitoring**: Detailed logs and debugging tools
- **Domain Flexibility**: Support for custom domains beyond subdomains

## 📋 Requirements

- A Linux server (Ubuntu 22.04 LTS recommended)
- A domain with wildcard DNS configured (pointing to your server's IP)
- Root access to the server

## 🔧 Installation

### 1. Configure DNS

First, set up your domain's DNS settings:

```
yourdomain.com     A     YOUR_SERVER_IP
*.yourdomain.com   A     YOUR_SERVER_IP
```

Wait for DNS propagation (this can take up to 24-48 hours).

### 2. Install the System

Download and run the installation script:

```bash
wget -O enhanced-setup-server.sh https://raw.githubusercontent.com/minhminhfreelancer/auto-install-nodejs/main/enhanced-setup-server.sh
chmod +x enhanced-setup-server.sh
sudo ./enhanced-setup-server.sh --domain yourdomain.com
```

The script will:
- Install required packages (Nginx, Node.js 20, PostgreSQL, etc.)
- Configure the server for auto-deployment
- Set up Let's Encrypt for SSL
- Create the deployment directory structure

## 📦 Usage

### Creating a New Application

```bash
sudo /opt/autodeploy/scripts/add-site.sh myapp https://github.com/username/repo.git
```

This will:
- Create a subdomain `myapp.yourdomain.com`
- Set up Let's Encrypt SSL
- Create a PostgreSQL database and user
- Configure an email account
- Set up continuous deployment from the Git repository

### Application Types

Specify the application type with the `--type` parameter:

```bash
sudo /opt/autodeploy/scripts/add-site.sh myapp https://github.com/username/repo.git --type fullstack
```

Available types:
- `static`: Basic static websites
- `spa`: Single Page Applications
- `node`: Node.js API/backend
- `fullstack`: Combined frontend (SPA) + backend (Node.js API)

### Using Custom Domains

```bash
sudo /opt/autodeploy/scripts/add-site.sh myapp https://github.com/username/repo.git --custom-domain app.example.com
```

### Managing Applications

**List all applications:**
```bash
sudo /opt/autodeploy/scripts/list-sites.sh
```

**Remove an application:**
```bash
sudo /opt/autodeploy/scripts/remove-site.sh myapp
```

**Debug an application:**
```bash
sudo /opt/autodeploy/scripts/debug.sh myapp
```

**Force deployment:**
```bash
sudo /opt/autodeploy/scripts/deploy.sh myapp
```

## ⚙️ Configuration Details

Each application comes with:

### Database Configuration

Environmental variables are automatically created in `.env`:
```
DB_HOST=localhost
DB_PORT=5432
DB_NAME=db_myapp
DB_USER=user_myapp
DB_PASSWORD=random_secure_password
DATABASE_URL=postgresql://user_myapp:random_secure_password@localhost:5432/db_myapp
```

### Email Configuration

```
SMTP_HOST=localhost
SMTP_PORT=25
SMTP_USER=noreply@myapp.yourdomain.com
SMTP_PASSWORD=random_secure_password
SMTP_FROM=noreply@myapp.yourdomain.com
```

### Application Structure

The system organizes each application in a clean directory structure:
- **Code**: `/opt/autodeploy/www/myapp/`
- **Git Repository**: `/opt/autodeploy/repos/myapp.git/`
- **Logs**: `/opt/autodeploy/logs/`
- **Configuration**: `/opt/autodeploy/config/sites/myapp.json`

## 🔍 Troubleshooting

### Debug Tool

Use the built-in debug tool for comprehensive diagnostics:

```bash
sudo /opt/autodeploy/scripts/debug.sh myapp
```

This will display:
- Configuration status
- Service status (Nginx, PostgreSQL, Node.js)
- Recent deployment logs
- SSL certificate status
- Connection tests

### Common Issues

1. **Subdomain not working**
   - Check DNS configuration with `dig myapp.yourdomain.com`
   - Verify Nginx configuration with `nginx -t`

2. **Deployment failing**
   - Check logs: `tail -f /opt/autodeploy/logs/deploy/myapp.log`
   - Verify Git repository is accessible

3. **Database connection issues**
   - Review database configuration: `cat /opt/autodeploy/config/sites/myapp_db.env`
   - Check PostgreSQL status: `systemctl status postgresql`

## 📝 License

MIT License - Feel free to use, modify, and distribute as needed.

## 💡 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

---

Created with ❤️ for the Node.js community by [freelancer.io.vn](https://freelancer.io.vn/)

---

<a name="tiếng-việt"></a>
# 🚀 Hệ Thống Tự Động Triển Khai Node.js

*[English](#english) | [Tiếng Việt](#tiếng-việt)*

Hệ thống triển khai tự động cho ứng dụng Node.js với khả năng tạo subdomain không cần cấu hình, SSL tự động, cấp phát cơ sở dữ liệu và triển khai liên tục.

Phát triển bởi [freelancer.io.vn](https://freelancer.io.vn/)

## ✨ Tính Năng

- **Hỗ Trợ Tên Miền Tùy Chỉnh**: Sử dụng tên miền riêng với DNS wildcard
- **Node.js 20 LTS**: Phiên bản LTS mới nhất được cấu hình sẵn
- **Tạo Subdomain Ngay Lập Tức**: Tự động tạo `tênứngdụng.tênmiền.com`
- **SSL Tự Động**: Chứng chỉ SSL Let's Encrypt với gia hạn tự động
- **Tích Hợp Cơ Sở Dữ Liệu**: PostgreSQL database và user cho mỗi ứng dụng
- **Cấu Hình Email**: Tài khoản SMTP cho mỗi ứng dụng
- **Triển Khai Liên Tục**: Tự động cập nhật từ Git mỗi 5 giây
- **Nhiều Loại Ứng Dụng**: Hỗ trợ trang tĩnh, SPA, backend Node.js và ứng dụng fullstack
- **Giám Sát Toàn Diện**: Công cụ ghi log và debug chi tiết
- **Linh Hoạt Tên Miền**: Hỗ trợ tên miền tùy chỉnh ngoài subdomain

## 📋 Yêu Cầu

- Máy chủ Linux (khuyến nghị Ubuntu 22.04 LTS)
- Tên miền với DNS wildcard đã cấu hình (trỏ đến IP máy chủ của bạn)
- Quyền root trên máy chủ

## 🔧 Cài Đặt

### 1. Cấu Hình DNS

Đầu tiên, thiết lập cấu hình DNS cho tên miền của bạn:

```
tenmiền.com     A     IP_MÁY_CHỦ_CỦA_BẠN
*.tenmiền.com   A     IP_MÁY_CHỦ_CỦA_BẠN
```

Đợi DNS lan truyền (có thể mất đến 24-48 giờ).

### 2. Cài Đặt Hệ Thống

Tải xuống và chạy script cài đặt:

```bash
wget -O enhanced-setup-server.sh https://raw.githubusercontent.com/minhminhfreelancer/auto-install-nodejs/main/enhanced-setup-server.sh
chmod +x enhanced-setup-server.sh
sudo ./enhanced-setup-server.sh --domain tenmiền.com
```

Script sẽ:
- Cài đặt các gói cần thiết (Nginx, Node.js 20, PostgreSQL, v.v.)
- Cấu hình máy chủ cho triển khai tự động
- Thiết lập Let's Encrypt cho SSL
- Tạo cấu trúc thư mục triển khai

## 📦 Sử Dụng

### Tạo Ứng Dụng Mới

```bash
sudo /opt/autodeploy/scripts/add-site.sh myapp https://github.com/username/repo.git
```

Lệnh này sẽ:
- Tạo subdomain `myapp.tenmiền.com`
- Thiết lập SSL Let's Encrypt
- Tạo cơ sở dữ liệu PostgreSQL và user
- Cấu hình tài khoản email
- Thiết lập triển khai liên tục từ repository Git

### Các Loại Ứng Dụng

Chỉ định loại ứng dụng với tham số `--type`:

```bash
sudo /opt/autodeploy/scripts/add-site.sh myapp https://github.com/username/repo.git --type fullstack
```

Các loại có sẵn:
- `static`: Trang web tĩnh cơ bản
- `spa`: Ứng dụng đơn trang (Single Page Applications)
- `node`: API/backend Node.js
- `fullstack`: Kết hợp frontend (SPA) + backend (Node.js API)

### Sử Dụng Tên Miền Tùy Chỉnh

```bash
sudo /opt/autodeploy/scripts/add-site.sh myapp https://github.com/username/repo.git --custom-domain app.example.com
```

### Quản Lý Ứng Dụng

**Liệt kê tất cả ứng dụng:**
```bash
sudo /opt/autodeploy/scripts/list-sites.sh
```

**Xóa ứng dụng:**
```bash
sudo /opt/autodeploy/scripts/remove-site.sh myapp
```

**Debug ứng dụng:**
```bash
sudo /opt/autodeploy/scripts/debug.sh myapp
```

**Triển khai thủ công:**
```bash
sudo /opt/autodeploy/scripts/deploy.sh myapp
```

## ⚙️ Chi Tiết Cấu Hình

Mỗi ứng dụng đi kèm với:

### Cấu Hình Cơ Sở Dữ Liệu

Biến môi trường được tự động tạo trong `.env`:
```
DB_HOST=localhost
DB_PORT=5432
DB_NAME=db_myapp
DB_USER=user_myapp
DB_PASSWORD=mật_khẩu_ngẫu_nhiên_an_toàn
DATABASE_URL=postgresql://user_myapp:mật_khẩu_ngẫu_nhiên_an_toàn@localhost:5432/db_myapp
```

### Cấu Hình Email

```
SMTP_HOST=localhost
SMTP_PORT=25
SMTP_USER=noreply@myapp.tenmiền.com
SMTP_PASSWORD=mật_khẩu_ngẫu_nhiên_an_toàn
SMTP_FROM=noreply@myapp.tenmiền.com
```

### Cấu Trúc Ứng Dụng

Hệ thống tổ chức mỗi ứng dụng trong cấu trúc thư mục rõ ràng:
- **Mã Nguồn**: `/opt/autodeploy/www/myapp/`
- **Repository Git**: `/opt/autodeploy/repos/myapp.git/`
- **Logs**: `/opt/autodeploy/logs/`
- **Cấu Hình**: `/opt/autodeploy/config/sites/myapp.json`

## 🔍 Xử Lý Sự Cố

### Công Cụ Debug

Sử dụng công cụ debug tích hợp để chẩn đoán toàn diện:

```bash
sudo /opt/autodeploy/scripts/debug.sh myapp
```

Công cụ này sẽ hiển thị:
- Trạng thái cấu hình
- Trạng thái dịch vụ (Nginx, PostgreSQL, Node.js)
- Logs triển khai gần đây
- Trạng thái chứng chỉ SSL
- Kiểm tra kết nối

### Vấn Đề Thường Gặp

1. **Subdomain không hoạt động**
   - Kiểm tra cấu hình DNS với `dig myapp.tenmiền.com`
   - Xác minh cấu hình Nginx với `nginx -t`

2. **Triển khai thất bại**
   - Kiểm tra logs: `tail -f /opt/autodeploy/logs/deploy/myapp.log`
   - Xác minh repository Git có thể truy cập được

3. **Vấn đề kết nối cơ sở dữ liệu**
   - Xem lại cấu hình cơ sở dữ liệu: `cat /opt/autodeploy/config/sites/myapp_db.env`
   - Kiểm tra trạng thái PostgreSQL: `systemctl status postgresql`

## 📝 Giấy Phép

Giấy phép MIT - Bạn có thể tự do sử dụng, sửa đổi và phân phối theo nhu cầu.

## 💡 Đóng Góp

Chúng tôi rất hoan nghênh mọi đóng góp! Vui lòng gửi Pull Request nếu bạn muốn đóng góp.

---

Tạo với ❤️ dành cho cộng đồng Node.js bởi [freelancer.io.vn](https://freelancer.io.vn/)
